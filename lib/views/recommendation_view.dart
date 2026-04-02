import 'package:flutter/material.dart';
import '../controlles/recommendation_controller.dart';
import 'recommendation_results_view.dart';

class RecommendationView extends StatefulWidget {
  const RecommendationView({super.key});

  @override
  State<RecommendationView> createState() => _RecommendationViewState();
}

class _RecommendationViewState extends State<RecommendationView> {
  static const primary = Color(0xFF5A3E9E);
  final RecommendationController _controller = RecommendationController();
  bool _isLoading = false;

  final TextEditingController _descriptionController = TextEditingController();

  String? _selectedField;

  bool _submitted = false;

  final List<String> _serviceFields = const [
    'Graphic Designers',
    'Marketing',
    'Software Developers',
    'Accounting',
    'Tutoring',
  ];

  bool get _isFieldValid => _selectedField != null;

  // تعديل فاطمه
  // تم إضافة RegExp جديد للتحقق من special characters
  // المسموح: الحروف الإنجليزية والعربية والأرقام والمسافات فقط
  final RegExp _specialCharsReg = RegExp(r'[^\u0600-\u06FFa-zA-Z0-9\s]');
  // نهاية تعديلات فاطمه

  bool get _isDescriptionValid {
    final text = _descriptionController.text.trim();

    if (text.isEmpty) return false;

    final hasLink = RegExp(
      r'((https?:\/\/)|(www\.)|\S+\.[a-zA-Z]{2,})',
      caseSensitive: false,
    ).hasMatch(text);

    if (hasLink) return false;

    final numbersOnly = RegExp(r'^\d+$').hasMatch(text);
    if (numbersOnly) return false;

    // تعديل فاطمه
    // تم إضافة شرط جديد لمنع special characters
    final hasSpecialCharacters = _specialCharsReg.hasMatch(text);
    if (hasSpecialCharacters) return false;
    // نهاية تعديلات فاطمه

    if (text.length >= 150) return false;

    return true;
  }

  Future<void> _findFreelancers() async {
    setState(() {
      _submitted = true;
    });

    if (!_isFieldValid || !_isDescriptionValid) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final results = await _controller.findFreelancers(
        serviceField: _selectedField!,
        description: _descriptionController.text.trim(),
      );

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecommendationResultsView(
            results: results,
            requestDescription: _descriptionController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    );
  }

  Widget _errorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final descriptionLength = _descriptionController.text.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Find the Right Freelancer'),
        backgroundColor: Colors.white,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('Service Field'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _submitted && !_isFieldValid
                        ? Colors.red
                        : Colors.grey.shade200,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedField,
                    hint: const Text('Select'),
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down),
                    items: _serviceFields.map((field) {
                      return DropdownMenuItem<String>(
                        value: field,
                        child: Text(field),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedField = value;
                      });
                    },
                  ),
                ),
              ),
              if (_submitted && !_isFieldValid)
                _errorText('Please select a service field.'),

              const SizedBox(height: 18),

              _sectionTitle('What do you need?'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _submitted && !_isDescriptionValid
                        ? Colors.red
                        : Colors.grey.shade200,
                  ),
                ),
                child: TextField(
                  controller: _descriptionController,
                  maxLength: 150,
                  maxLines: 4,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'e.g. I need a logo in black color',
                    counterText: '',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$descriptionLength / 150',
                  style: TextStyle(fontSize: 12, color: Color(0xFFBDBDBD)),
                ),
              ),
              if (_submitted && !_isDescriptionValid)
                _errorText(
                  _descriptionController.text.trim().isEmpty
                      ? 'Please describe what you need.'
                      : RegExp(
                          r'((https?:\/\/)|(www\.)|\S+\.[a-zA-Z]{2,})',
                          caseSensitive: false,
                        ).hasMatch(_descriptionController.text.trim())
                      ? 'Links are not allowed.'
                      : RegExp(
                          r'^\d+$',
                        ).hasMatch(_descriptionController.text.trim())
                      ? 'Numbers only are not allowed.'
                      // تعديل فاطمه
                      // تم إضافة رسالة جديدة عند وجود special characters
                      : _specialCharsReg.hasMatch(
                          _descriptionController.text.trim(),
                        )
                      ? 'Special characters are not allowed.'
                      // نهاية تعديلات فاطمه
                      : _descriptionController.text.trim().length >= 150
                      ? 'Maximum limit is 150 characters.'
                      : 'Please describe what you need.',
                ),

              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _findFreelancers,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Find Freelancers',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SegmentBar extends StatelessWidget {
  const _SegmentBar({
    required this.options,
    required this.value,
    required this.onChanged,
    required this.purple,
  });

  final List<String> options;
  final String? value;
  final void Function(String v) onChanged;
  final Color purple;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: purple.withOpacity(0.25), width: 1.2),
      ),
      child: Row(
        children: options.map((o) {
          final selected = o == value;
          return Expanded(
            child: InkWell(
              onTap: () => onChanged(o),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? purple.withOpacity(0.14)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    o,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: selected ? purple : Colors.grey.shade700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
