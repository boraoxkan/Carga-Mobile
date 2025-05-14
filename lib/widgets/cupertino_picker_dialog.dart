// lib/widgets/cupertino_picker_dialog.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

Future<String?> showCupertinoPickerDialog({
  required BuildContext context,
  required List<String> items,
  required String title,
}) async {
  int selectedIndex = 0;
  return await showCupertinoModalPopup<String>(
    context: context,
    builder: (BuildContext context) {
      return Material(
        child: Container(
          height: MediaQuery.of(context).viewInsets.bottom + 250,
          alignment: Alignment.bottomCenter,
          child: Container(
            color: Colors.white,
            height: 250,
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  alignment: Alignment.center,
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ),
                Expanded(
                  child: CupertinoPicker(
                    itemExtent: 32,
                    backgroundColor: Colors.white,
                    onSelectedItemChanged: (int index) {
                      selectedIndex = index;
                    },
                    children: items
                        .map((e) => Center(
                              child: Text(
                                e,
                                style: const TextStyle(fontSize: 18, color: Colors.black),
                              ),
                            ))
                        .toList(),
                  ),
                ),
                CupertinoButton(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: const Text(
                    "Seç",
                    style: TextStyle(fontSize: 18, color: Colors.purple),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop(items[selectedIndex]);
                  },
                )
              ],
            ),
          ),
        ),
      );
    },
  );
}
