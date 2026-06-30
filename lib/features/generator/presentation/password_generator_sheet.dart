import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/password_generator.dart';

class PasswordGeneratorSheet extends StatefulWidget {
  final Function(String) onPasswordGenerated;

  const PasswordGeneratorSheet({
    super.key,
    required this.onPasswordGenerated,
  });

  static Future<void> show(BuildContext context, Function(String) onApply) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => PasswordGeneratorSheet(onPasswordGenerated: onApply),
    );
  }

  @override
  State<PasswordGeneratorSheet> createState() => _PasswordGeneratorSheetState();
}

class _PasswordGeneratorSheetState extends State<PasswordGeneratorSheet> {
  int _length = 16;
  bool _includeUppercase = true;
  bool _includeNumbers = true;
  bool _includeSymbols = true;
  String _currentPassword = '';

  @override
  void initState() {
    super.initState();
    _generatePassword();
  }

  void _generatePassword() {
    setState(() {
      _currentPassword = PasswordGenerator.generate(
        length: _length,
        includeUppercase: _includeUppercase,
        includeNumbers: _includeNumbers,
        includeSymbols: _includeSymbols,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Password Generator',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Password Display
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).primaryColor, width: 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _currentPassword,
                    style: const TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.teal),
                  onPressed: _generatePassword,
                ),
                IconButton(
                  icon: const Icon(Icons.copy, color: Colors.teal),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _currentPassword));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Length Slider
          Row(
            children: [
              const Text('Length', style: TextStyle(fontSize: 16)),
              const Spacer(),
              Text('$_length', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          Slider(
            value: _length.toDouble(),
            min: 8,
            max: 64,
            activeColor: Colors.teal,
            onChanged: (val) {
              setState(() {
                _length = val.toInt();
                _generatePassword();
              });
            },
          ),
          
          // Toggles
          SwitchListTile(
            title: const Text('Uppercase Letters (A-Z)'),
            value: _includeUppercase,
            activeTrackColor: Colors.teal,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              if (!val && !_includeNumbers && !_includeSymbols) return; // Prevent turning off all
              setState(() {
                _includeUppercase = val;
                _generatePassword();
              });
            },
          ),
          SwitchListTile(
            title: const Text('Numbers (0-9)'),
            value: _includeNumbers,
            activeTrackColor: Colors.teal,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              if (!val && !_includeUppercase && !_includeSymbols) return;
              setState(() {
                _includeNumbers = val;
                _generatePassword();
              });
            },
          ),
          SwitchListTile(
            title: const Text('Symbols (!@#%)'),
            value: _includeSymbols,
            activeTrackColor: Colors.teal,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              if (!val && !_includeUppercase && !_includeNumbers) return;
              setState(() {
                _includeSymbols = val;
                _generatePassword();
              });
            },
          ),
          
          const SizedBox(height: 24),
          
          ElevatedButton(
            onPressed: () {
              widget.onPasswordGenerated(_currentPassword);
              Navigator.of(context).pop();
            },
            child: const Text('Use Password'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
