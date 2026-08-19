import 'package:flutter/material.dart';
import 'package:plant_lab/core/config/app_config.dart';

class OperationalModeBanner extends StatelessWidget {
  const OperationalModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppConfig.operationalWritesEnabled) {
      return const SizedBox.shrink();
    }

    return const Material(
      color: Color(0xFFFFF3CD),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.lock_outline, size: 18, color: Color(0xFF7A4D00)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mode read-only aktif — data dapat dilihat, tetapi perubahan '
                  'belum diizinkan selama tahap UAT.',
                  style: TextStyle(
                    color: Color(0xFF7A4D00),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
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
