import 'package:flutter/material.dart';
import '../../theme/smartmedia_theme.dart';

class SearchCapsule extends StatelessWidget {
  const SearchCapsule({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: SMColors.surfaceElevated,
        boxShadow: const [
          // Inner-shadow simulation
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 8,
            offset: Offset(0, 2),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Color(0x14FFFFFF),
            blurRadius: 1,
            offset: Offset(0, -1),
          ),
        ],
        border: Border.all(color: SMColors.glassBorder),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: SMColors.textPrimary, fontSize: 15),
        cursorColor: SMColors.indigo,
        decoration: const InputDecoration(
          hintText: 'Search trending GIFs...',
          hintStyle: TextStyle(color: SMColors.muted),
          prefixIcon: Icon(Icons.search_rounded, color: SMColors.muted),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
        ),
      ),
    );
  }
}
