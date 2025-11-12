import 'dart:async';
import 'package:budget/database/tables.dart';
import 'package:budget/pages/addTransactionPage.dart';
import 'package:budget/pages/addEmailTemplate.dart';
import 'package:budget/struct/databaseGlobal.dart';
import 'package:budget/struct/settings.dart';
import 'package:budget/widgets/navigationFramework.dart';
import 'package:budget/widgets/util/appLinks.dart';
import 'package:budget/widgets/framework/pageFramework.dart';
import 'package:budget/widgets/settingsContainers.dart';
import 'package:budget/widgets/statusBox.dart';
import 'package:budget/widgets/openContainerNavigation.dart';
import 'package:budget/widgets/button.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:budget/functions.dart';

StreamSubscription<dynamic>? smsListenerSubscription;
List<Map<String, dynamic>> recentCapturedSMS = [];

// Method channel for SMS communication with native Android
const MethodChannel _smsMethodChannel = MethodChannel('com.budget.tracker_app/sms');
const EventChannel _smsEventChannel = EventChannel('com.budget.tracker_app/sms_stream');

Future initSMSScanning() async {
  if (getPlatform(ignoreEmulation: true) != PlatformOS.isAndroid) return;
  smsListenerSubscription?.cancel();

  if (appStateSettings["smsScanning"] != true) return;

  bool status = await requestSMSPermission();

  if (status == true) {
    smsListenerSubscription = _smsEventChannel.receiveBroadcastStream().listen(onSMSReceived);
  }
}

Future<bool> requestSMSPermission() async {
  try {
    final bool status = await _smsMethodChannel.invokeMethod('requestSMSPermission');
    return status;
  } catch (e) {
    print('Error requesting SMS permission: $e');
    return false;
  }
}

Future<bool> checkSMSPermission() async {
  try {
    final bool status = await _smsMethodChannel.invokeMethod('checkSMSPermission');
    return status;
  } catch (e) {
    print('Error checking SMS permission: $e');
    return false;
  }
}

onSMSReceived(dynamic smsData) async {
  if (smsData is Map) {
    String sender = smsData['sender'] ?? '';
    String body = smsData['body'] ?? '';
    int timestamp = smsData['timestamp'] ?? DateTime.now().millisecondsSinceEpoch;
    DateTime dateTime = DateTime.fromMillisecondsSinceEpoch(timestamp);

    print('SMS received from $sender: $body');

    // Store in recent SMS list
    recentCapturedSMS.insert(0, {
      'sender': sender,
      'body': body,
      'timestamp': dateTime,
    });
    if (recentCapturedSMS.length > 50) {
      recentCapturedSMS = recentCapturedSMS.take(50).toList();
    }

    // Process the SMS message to create transaction
    await queueTransactionFromSMS(body, dateTime: dateTime);
  }
}

String? getTransactionTitleFromSMS(
    String message, String? before, String? after) {
  try {
    if (before == null || after == null) return null;

    int startIndex = message.indexOf(before);
    if (startIndex == -1) return null;

    startIndex += before.length;
    int endIndex = message.indexOf(after, startIndex);
    if (endIndex == -1) return null;

    String result = message.substring(startIndex, endIndex).trim();
    return result.isEmpty ? null : result;
  } catch (e) {
    print('Error extracting title: $e');
    return null;
  }
}

double? getTransactionAmountFromSMS(
    String message, String? before, String? after) {
  try {
    if (before == null || after == null) return null;

    int startIndex = message.indexOf(before);
    if (startIndex == -1) return null;

    startIndex += before.length;
    int endIndex = message.indexOf(after, startIndex);
    if (endIndex == -1) return null;

    String amountString = message.substring(startIndex, endIndex).trim();

    // Remove currency symbols and commas
    amountString = amountString.replaceAll(RegExp(r'[^\d.]'), '');

    return double.tryParse(amountString);
  } catch (e) {
    print('Error extracting amount: $e');
    return null;
  }
}

Future queueTransactionFromSMS(String smsBody,
    {bool willPushRoute = true, DateTime? dateTime}) async {
  String? title;
  double? amountDouble;
  List<ScannerTemplate> scannerTemplates =
      await database.getAllScannerTemplates();
  ScannerTemplate? templateFound;

  for (ScannerTemplate scannerTemplate in scannerTemplates) {
    if (smsBody.contains(scannerTemplate.contains)) {
      templateFound = scannerTemplate;
      title = getTransactionTitleFromSMS(
          smsBody,
          scannerTemplate.titleTransactionBefore,
          scannerTemplate.titleTransactionAfter);
      amountDouble = getTransactionAmountFromSMS(
          smsBody,
          scannerTemplate.amountTransactionBefore,
          scannerTemplate.amountTransactionAfter);
      break;
    }
  }

  if (templateFound == null) return false;

  if (amountDouble == null || title == null) return false;

  TransactionCategory? category;
  TransactionAssociatedTitleWithCategory? foundTitle =
      (await database.getSimilarAssociatedTitles(title: title, limit: 1))
          .firstOrNull;
  category = foundTitle?.category;
  if (category == null) {
    category = await database
        .getCategoryInstanceOrNull(templateFound.defaultCategoryFk);
  }

  TransactionWallet? wallet = templateFound.walletFk == "-1"
      ? null
      : await database.getWalletInstanceOrNull(templateFound.walletFk);

  if (willPushRoute) {
    pushRoute(
      null,
      AddTransactionPage(
        useCategorySelectedIncome: true,
        routesToPopAfterDelete: RoutesToPopAfterDelete.None,
        selectedAmount: amountDouble,
        selectedTitle: title,
        selectedCategory: category,
        startInitialAddTransactionSequence: false,
        selectedWallet: wallet,
        selectedDate: dateTime,
      ),
    );
  } else {
    processAddTransactionFromParams(navigatorKey.currentContext!, {
      'amount': amountDouble.toString(),
      'name': title,
      'categoryID': category?.categoryPk ?? "",
      'walletID': wallet?.walletPk ?? "",
      'date': (dateTime ?? DateTime.now()).toIso8601String(),
    });
  }

  return true;
}

class InitializeSMSService extends StatefulWidget {
  const InitializeSMSService({required this.child, super.key});
  final Widget child;

  @override
  State<InitializeSMSService> createState() => _InitializeSMSServiceState();
}

class _InitializeSMSServiceState extends State<InitializeSMSService> {
  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, () async {
      initSMSScanning();
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// SMS Settings Page UI
class AutoTransactionsPageSMS extends StatefulWidget {
  const AutoTransactionsPageSMS({Key? key}) : super(key: key);

  @override
  State<AutoTransactionsPageSMS> createState() => _AutoTransactionsPageSMSState();
}

class _AutoTransactionsPageSMSState extends State<AutoTransactionsPageSMS> {
  @override
  void initState() {
    super.initState();
  }

  List<String> getSMSMessagesList() {
    return recentCapturedSMS.map((sms) {
      String sender = sms['sender'] ?? 'Unknown';
      String body = sms['body'] ?? '';
      return 'From: $sender\n$body';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return PageFramework(
      dragDownToDismiss: true,
      title: "SMS Auto Transactions",
      actions: [
        RefreshButton(
          timeout: Duration.zero,
          onTap: () async {
            loadingIndeterminateKey.currentState?.setVisibility(true);
            setState(() {});
            loadingIndeterminateKey.currentState?.setVisibility(false);
          },
        ),
      ],
      listWidgets: [
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 5, start: 20, end: 20),
          child: TextFont(
            text: "Automatically create transactions from bank SMS messages. Set up templates to parse transaction details from your bank's SMS format.",
            fontSize: 14,
            maxLines: 10,
          ),
        ),
        SettingsContainerSwitch(
          onSwitched: (value) async {
            await updateSettings("smsScanning", value, updateGlobalState: false);
            if (value == true) {
              bool status = await requestSMSPermission();
              if (status == false) {
                await updateSettings("smsScanning", false, updateGlobalState: false);
              } else {
                initSMSScanning();
              }
            } else {
              smsListenerSubscription?.cancel();
            }
            setState(() {});
          },
          title: "Enable SMS Scanning",
          description: "When an SMS is received, automatically parse and create a transaction. You must create a template below so Cashew understands your bank's SMS format.",
          initialValue: appStateSettings["smsScanning"],
        ),
        StreamBuilder<List<ScannerTemplate>>(
          stream: database.watchAllScannerTemplates(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              if (snapshot.data!.length <= 0) {
                return Padding(
                  padding: const EdgeInsetsDirectional.all(5),
                  child: StatusBox(
                    title: "SMS Template Missing",
                    description: "Please add a template to parse your bank's SMS messages.",
                    icon: appStateSettings["outlinedIcons"]
                        ? Icons.warning_outlined
                        : Icons.warning_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                );
              }
              return Column(
                children: [
                  for (ScannerTemplate scannerTemplate in snapshot.data!)
                    ScannerTemplateEntry(
                      messagesList: getSMSMessagesList(),
                      scannerTemplate: scannerTemplate,
                    )
                ],
              );
            } else {
              return Container();
            }
          },
        ),
        OpenContainerNavigation(
          openPage: AddEmailTemplate(
            messagesList: getSMSMessagesList(),
          ),
          borderRadius: 15,
          button: (openContainer) {
            return Button(
              label: "Add SMS Template",
              onTap: openContainer,
            );
          },
        ),
        if (recentCapturedSMS.isNotEmpty)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 20, start: 20, end: 20),
            child: TextFont(
              text: "Recent SMS Messages (${recentCapturedSMS.length})",
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        for (var sms in recentCapturedSMS.take(10))
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 20, vertical: 5),
            child: Container(
              padding: EdgeInsetsDirectional.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFont(
                    text: "From: ${sms['sender']}",
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  SizedBox(height: 5),
                  TextFont(
                    text: sms['body'],
                    fontSize: 12,
                    maxLines: 10,
                  ),
                  SizedBox(height: 5),
                  TextFont(
                    text: sms['timestamp'].toString(),
                    fontSize: 10,
                    textColor: Theme.of(context).colorScheme.onSecondaryContainer.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// Scanner template entry widget (reused from notification scanner)
class ScannerTemplateEntry extends StatelessWidget {
  final ScannerTemplate scannerTemplate;
  final List<String> messagesList;

  const ScannerTemplateEntry({
    Key? key,
    required this.scannerTemplate,
    required this.messagesList,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return OpenContainerNavigation(
      openPage: AddEmailTemplate(
        scannerTemplate: scannerTemplate,
        messagesList: messagesList,
      ),
      borderRadius: 15,
      button: (openContainer) {
        return Padding(
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 5, vertical: 2.5),
          child: Button(
            label: scannerTemplate.contains,
            onTap: openContainer,
          ),
        );
      },
    );
  }
}
