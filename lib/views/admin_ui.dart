import 'package:flutter/material.dart';

const Color kAdminPrimary = Color(0xFF5A3E9E);
const Color kAdminBackground = Color(0xFFFAF8FF);
const Color kAdminSurface = Colors.white;
const Color kAdminSoftSurface = Color(0xFFF5F0FF);
const Color kAdminBorder = Color(0xFFE6DDF7);
const Color kAdminTextPrimary = Color(0xFF24163A);
const Color kAdminTextSecondary = Color(0xFF6F6780);
const Color kAdminWarning = Color(0xFFEF8F2F);
const Color kAdminSuccess = Color(0xFF2E9B62);
const Color kAdminDanger = Color(0xFFC75A5A);
const Color kAdminMuted = Color(0xFF8A8598);
const double kAdminRadius = 16;
const double kAdminPagePadding = 20;
const double kAdminCardPadding = 18;

BoxDecoration adminCardDecoration({Color color = kAdminSurface}) {
  return BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(kAdminRadius),
    border: Border.all(color: kAdminBorder),
    boxShadow: [
      BoxShadow(
        color: kAdminPrimary.withOpacity(0.06),
        blurRadius: 16,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

InputDecoration adminSearchDecoration({
  required String hintText,
  IconData prefixIcon = Icons.search_rounded,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: kAdminTextSecondary),
    prefixIcon: Icon(prefixIcon, color: kAdminPrimary),
    filled: true,
    fillColor: kAdminSurface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kAdminBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: kAdminBorder),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(16)),
      borderSide: BorderSide(color: kAdminPrimary),
    ),
  );
}

String adminStatusLabel(String status) {
  final normalized = status.trim();
  if (normalized.isEmpty) return '-';

  return normalized
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map(
        (part) =>
            '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
      )
      .join(' ');
}

Color adminStatusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'under_review':
      return kAdminWarning;
    case 'resolved':
    case 'valid':
      return kAdminSuccess;
    case 'dismissed':
    case 'invalid':
      return kAdminMuted;
    case 'admin_terminated':
    case 'blocked':
      return kAdminDanger;
    case 'requested':
    case 'open':
    case 'submitted':
    case 'pending':
    default:
      return kAdminPrimary;
  }
}

class AdminPageIntro extends StatelessWidget {
  const AdminPageIntro({
    super.key,
    required this.title,
    required this.subtitle,
    this.eyebrow,
  });

  final String title;
  final String subtitle;
  final String? eyebrow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(
        kAdminPagePadding,
        18,
        kAdminPagePadding,
        14,
      ),
      padding: const EdgeInsets.all(kAdminCardPadding),
      decoration: adminCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if ((eyebrow ?? '').trim().isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kAdminSoftSurface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                eyebrow!,
                style: const TextStyle(
                  color: kAdminPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Text(
            title,
            style: const TextStyle(
              color: kAdminPrimary,
              fontSize: 23,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: const TextStyle(
              color: kAdminTextSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminSearchField extends StatelessWidget {
  const AdminSearchField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hintText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kAdminPagePadding,
        0,
        kAdminPagePadding,
        12,
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: adminSearchDecoration(hintText: hintText),
      ),
    );
  }
}

class AdminFilterChip extends StatelessWidget {
  const AdminFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
      backgroundColor: kAdminSurface,
      selectedColor: kAdminPrimary,
      labelStyle: TextStyle(
        color: selected ? Colors.white : kAdminPrimary,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
      ),
      side: const BorderSide(color: kAdminBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class AdminStatusChip extends StatelessWidget {
  const AdminStatusChip({
    super.key,
    required this.status,
    this.label,
  });

  final String status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = adminStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Text(
        label ?? adminStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class AdminMetaPill extends StatelessWidget {
  const AdminMetaPill({
    super.key,
    required this.label,
    required this.icon,
    this.color = kAdminPrimary,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminLoadingState extends StatelessWidget {
  const AdminLoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: kAdminPrimary),
    );
  }
}

class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: kAdminSoftSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: kAdminPrimary, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kAdminTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: kAdminTextSecondary,
                fontSize: 13.5,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AdminSectionCard extends StatelessWidget {
  const AdminSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(kAdminCardPadding),
      decoration: adminCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: kAdminPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class AdminInfoPanel extends StatelessWidget {
  const AdminInfoPanel({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kAdminSoftSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kAdminBorder),
      ),
      child: child,
    );
  }
}

class AdminProfilePreviewCard extends StatelessWidget {
  const AdminProfilePreviewCard({
    super.key,
    required this.name,
    required this.email,
    required this.accountType,
    this.photoUrl,
    this.secondaryPillLabel,
    this.secondaryPillIcon,
    this.secondaryPillColor = kAdminWarning,
    this.onTap,
  });

  final String name;
  final String email;
  final String accountType;
  final String? photoUrl;
  final String? secondaryPillLabel;
  final IconData? secondaryPillIcon;
  final Color secondaryPillColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final normalizedPhoto = (photoUrl ?? '').trim();
    final normalizedEmail = email.trim();
    final normalizedRole = accountType.trim();
    final normalizedSecondary = (secondaryPillLabel ?? '').trim();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kAdminSoftSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kAdminBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    backgroundImage: normalizedPhoto.isNotEmpty
                        ? NetworkImage(normalizedPhoto)
                        : null,
                    child: normalizedPhoto.isEmpty
                        ? const Icon(
                            Icons.person_outline_rounded,
                            color: kAdminPrimary,
                            size: 28,
                          )
                        : null,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: kAdminTextPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (normalizedRole.isNotEmpty)
                              AdminMetaPill(
                                label: normalizedRole,
                                icon: Icons.badge_outlined,
                              ),
                            if (normalizedSecondary.isNotEmpty)
                              AdminMetaPill(
                                label: normalizedSecondary,
                                icon: secondaryPillIcon ??
                                    Icons.info_outline_rounded,
                                color: secondaryPillColor,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.chevron_right_rounded,
                        color: kAdminPrimary,
                        size: 20,
                      ),
                    ),
                ],
              ),
              if (normalizedEmail.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(height: 1, color: kAdminBorder),
                const SizedBox(height: 14),
                AdminKeyValueRow(label: 'Email', value: normalizedEmail),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AdminKeyValueRow extends StatelessWidget {
  const AdminKeyValueRow({
    super.key,
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: const TextStyle(
                color: kAdminTextSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: kAdminTextPrimary,
                fontSize: 13.5,
                height: 1.42,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminUserProfilePage extends StatelessWidget {
  const AdminUserProfilePage({
    super.key,
    required this.title,
    required this.name,
    required this.email,
    required this.accountType,
    this.photoUrl,
    this.secondaryPillLabel,
    this.secondaryPillIcon,
    this.secondaryPillColor = kAdminWarning,
  });

  final String title;
  final String name;
  final String email;
  final String accountType;
  final String? photoUrl;
  final String? secondaryPillLabel;
  final IconData? secondaryPillIcon;
  final Color secondaryPillColor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kAdminBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: kAdminPrimary,
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          kAdminPagePadding,
          20,
          kAdminPagePadding,
          28,
        ),
        children: [
          AdminSectionCard(
            title: 'Profile Summary',
            child: AdminProfilePreviewCard(
              name: name,
              email: email,
              accountType: accountType,
              photoUrl: photoUrl,
              secondaryPillLabel: secondaryPillLabel,
              secondaryPillIcon: secondaryPillIcon,
              secondaryPillColor: secondaryPillColor,
            ),
          ),
        ],
      ),
    );
  }
}

class AdminActionMenuButton extends StatelessWidget {
  const AdminActionMenuButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: adminOutlinedButtonStyle(),
      icon: const Icon(Icons.more_horiz_rounded, size: 18),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class AdminActionSheetTile extends StatelessWidget {
  const AdminActionSheetTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = enabled ? iconColor : Colors.black38;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: enabled
                ? iconColor.withOpacity(0.10)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: foregroundColor),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: foregroundColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: Colors.black.withOpacity(enabled ? 0.58 : 0.38),
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

ButtonStyle adminFilledButtonStyle({
  Color backgroundColor = kAdminPrimary,
  Color foregroundColor = Colors.white,
}) {
  return ElevatedButton.styleFrom(
    backgroundColor: backgroundColor,
    foregroundColor: foregroundColor,
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    elevation: 0,
  );
}

ButtonStyle adminOutlinedButtonStyle({Color color = kAdminPrimary}) {
  return OutlinedButton.styleFrom(
    foregroundColor: color,
    side: BorderSide(color: color.withOpacity(0.22)),
    minimumSize: const Size(0, 44),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}
