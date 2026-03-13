import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:math_expressions/math_expressions.dart' hide Stack;

class CalculatorToolPage extends StatefulWidget {
  const CalculatorToolPage({super.key});

  @override
  State<CalculatorToolPage> createState() => _CalculatorToolPageState();
}

class _CalculatorToolPageState extends State<CalculatorToolPage> {
  bool _justCalculated = false;
  String _userInput = '';
  String _oldFormula = '';

  final List<String> _buttons = [
    'C',
    '⁺∕₋',
    '%',
    '÷',
    '7',
    '8',
    '9',
    '×',
    '4',
    '5',
    '6',
    '−',
    '1',
    '2',
    '3',
    '+',
    '.',
    '0',
    'backspace',
    '=',
  ];

  void buttonTapped(String value) {
    setState(() {
      if (_justCalculated && (double.tryParse(value) != null || value == '.') ||
          _userInput == 'Error') {
        _userInput = '';
        _oldFormula = '';
        _justCalculated = false;
      }
      if (value == 'C') {
        _userInput = '';
        _oldFormula = '';
        _justCalculated = false;
      } else if (value == 'backspace') {
        if (_userInput.isNotEmpty) {
          _userInput = _userInput.substring(0, _userInput.length - 1);
        }
        _justCalculated = false;
      } else if (value == '=') {
        calculateResult();
        _justCalculated = _userInput != 'Error';
      } else if (value == '⁺∕₋') {
        if (_userInput.isNotEmpty && !_userInput.startsWith('-')) {
          _userInput = '-$_userInput';
        } else if (_userInput.startsWith('-')) {
          _userInput = _userInput.substring(1);
        }
        _justCalculated = false;
      } else if (value == '%') {
        if (_userInput.isNotEmpty) {
          _userInput += '%';
        }
        _justCalculated = false;
      } else {
        _userInput += value;
        _justCalculated = false;
      }
    });
  }

  void calculateResult() {
    try {
      final String finalInput = _userInput
          .replaceAll('×', '*')
          .replaceAll('−', '-')
          .replaceAll('÷', '/')
          .replaceAll('%', '/100');
      final p = ShuntingYardParser();
      final Expression exp = p.parse(finalInput);
      final evaluator = RealEvaluator();
      final num eval = evaluator.evaluate(exp);
      setState(() {
        _oldFormula = _userInput;
        _userInput = eval.toString();
      });
    } on Exception catch (_) {
      setState(() {
        _oldFormula = _userInput;
        _userInput = 'Error';
      });
      // It works
      // ignore: avoid_catching_errors
    } on Error catch (_) {
      setState(() {
        _oldFormula = _userInput;
        _userInput = 'Error';
      });
    }
  }

  Color getButtonColor(String text) {
    switch (text) {
      case 'C':
      case '⁺∕₋':
      case '%':
        return Theme.of(context).colorScheme.surfaceBright;
      case '=':
      case '÷':
      case '×':
      case '−':
      case '+':
        return Theme.of(context).colorScheme.inversePrimary;
      default:
        return Theme.of(context).colorScheme.surfaceContainerLow;
    }
  }

  Color getTextColor(String text) {
    if (text == 'C' || text == 'backspace' || text == '=' || isOperator(text)) {
      return Colors.white;
    }
    return Colors.white70;
  }

  bool isOperator(String text) {
    return ['÷', '×', '−', '+', '='].contains(text);
  }

  String _formatDecimalAnswer(String answer) {
    if (answer.isEmpty || answer == 'Error') return answer;
    // Format each number in the answer string separately
    final numberExp = RegExp(r'-?\d*\.?\d+');
    final commaFormat = NumberFormat('#,##0');
    final commaDecimalFormat = NumberFormat('#,##0.########');

    return answer.replaceAllMapped(numberExp, (match) {
      final String numStr = match.group(0) ?? '';
      final num? value = num.tryParse(numStr);
      if (value == null) return numStr;
      if (value is int || value == value.roundToDouble()) {
        return commaFormat.format(value);
      }
      return commaDecimalFormat.format(value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: const Text('Calculator'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            Expanded(
              child: Container(
                alignment: Alignment.bottomRight,
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Positioned(
                      top: 10,
                      child: Text(
                        _formatDecimalAnswer(_oldFormula),
                        style: GoogleFonts.workSans(
                          fontSize: 24,
                          fontWeight: FontWeight.w300,
                          color: const Color.fromARGB(255, 125, 125, 125),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -12,
                      child: Text(
                        _formatDecimalAnswer(_userInput),
                        style: GoogleFonts.workSans(
                          fontSize: 90,
                          fontWeight: FontWeight.w300,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 12),
              child: GridView.count(
                crossAxisCount: 4,
                crossAxisSpacing: 18,
                mainAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                children: List.generate(_buttons.length, (index) {
                  final String btn = _buttons[index];
                  if (btn == 'backspace') {
                    return _CustomButton(
                      text: '',
                      icon: Symbols.backspace,
                      onTap: () => buttonTapped('backspace'),
                      color: getButtonColor(btn),
                      textColor: getTextColor(btn),
                    );
                  }
                  return _CustomButton(
                    text: btn,
                    onTap: () => buttonTapped(btn),
                    color: getButtonColor(btn),
                    textColor: getTextColor(btn),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomButton extends StatelessWidget {
  const _CustomButton({
    required String text,
    required void Function() onTap,
    required Color color,
    required Color textColor,
    IconData? icon,
  }) : _textColor = textColor,
       _color = color,
       _onTap = onTap,
       _text = text,
       _icon = icon;

  final String _text;
  final IconData? _icon;
  final VoidCallback _onTap;
  final Color _color;
  final Color _textColor;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _color,
        foregroundColor: _textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        padding: const EdgeInsets.symmetric(vertical: 2),
        shadowColor: Colors.black.withAlpha((0.3 * 255).toInt()),
        elevation: 3,
      ),
      child: _icon == null
          ? Text(
              _text,
              style: GoogleFonts.workSans(
                fontSize: 36,
                fontWeight: FontWeight.w300,
                color: _textColor,
              ),
            )
          : Icon(_icon, color: _textColor, fill: 0, size: 38, weight: 100),
    );
  }
}
