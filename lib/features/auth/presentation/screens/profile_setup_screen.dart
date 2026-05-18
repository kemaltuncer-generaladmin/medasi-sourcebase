import 'package:flutter/material.dart';

import '../../../drive/presentation/screens/drive_workspace_screen.dart';
import '../../data/sourcebase_auth_backend.dart';
import '../widgets/auth_widgets.dart';
import 'login_screen.dart';
import 'verify_email_screen.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  static const route = '/profile-setup';

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final facultyController = TextEditingController();
  String department = 'Tıp';
  bool loading = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (SourceBaseAuthBackend.currentUser == null) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          LoginScreen.route,
          (_) => false,
        );
        return;
      }
      if (!SourceBaseAuthBackend.currentUserHasVerifiedEmail) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          VerifyEmailScreen.route,
          (_) => false,
        );
      }
    });
    final metadata = SourceBaseAuthBackend.currentUser?.userMetadata ?? {};
    final faculty = metadata['sourcebase_faculty']?.toString().trim() ?? '';
    final savedDepartment =
        metadata['sourcebase_department']?.toString().trim() ?? '';
    facultyController.text = faculty;
    if (['Tıp', 'Diş Hekimliği', 'Hemşirelik'].contains(savedDepartment)) {
      department = savedDepartment;
    }
  }

  @override
  void dispose() {
    facultyController.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    if (loading) {
      return;
    }
    if (facultyController.text.trim().isEmpty) {
      setState(() => errorMessage = 'Fakülte bilgisini doldurmalısın.');
      return;
    }
    if (department.trim().isEmpty) {
      setState(() => errorMessage = 'Bölüm bilgisini seçmelisin.');
      return;
    }
    if (!SourceBaseAuthBackend.isConfigured ||
        SourceBaseAuthBackend.initializationError != null) {
      setState(
        () => errorMessage = SourceBaseAuthBackend.friendlyError(
          SourceBaseAuthBackend.initializationError ?? Object(),
        ),
      );
      return;
    }
    if (SourceBaseAuthBackend.currentUser == null) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        LoginScreen.route,
        (_) => false,
      );
      return;
    }
    if (!SourceBaseAuthBackend.currentUserHasVerifiedEmail) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        VerifyEmailScreen.route,
        (_) => false,
      );
      return;
    }
    setState(() {
      loading = true;
      errorMessage = null;
    });
    try {
      await SourceBaseAuthBackend.updateSourceBaseProfile(
        SourceBaseProfile(
          faculty: facultyController.text,
          department: department,
        ),
      );
      if (!mounted) {
        return;
      }
      Navigator.pushNamedAndRemoveUntil(
        context,
        DriveWorkspaceScreen.route,
        (_) => false,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => errorMessage = SourceBaseAuthBackend.friendlyError(error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScreenFrame(
      children: [
        const AuthHeader(
          title: 'Bilgilerini\ntamamla',
          subtitle: 'SourceBase deneyimini sana uygun\nhale getirelim.',
          art: AuthArtType.register,
        ),
        const SizedBox(height: 34),
        AuthTextField(
          icon: Icons.account_balance_outlined,
          hint: 'Fakülte / Üniversite',
          controller: facultyController,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: const Color(0xFFD9E3F2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: department,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
              items: const [
                DropdownMenuItem(value: 'Tıp', child: Text('Tıp')),
                DropdownMenuItem(
                  value: 'Diş Hekimliği',
                  child: Text('Diş Hekimliği'),
                ),
                DropdownMenuItem(
                  value: 'Hemşirelik',
                  child: Text('Hemşirelik'),
                ),
              ],
              onChanged: loading
                  ? null
                  : (value) {
                      if (value != null) {
                        setState(() => department = value);
                      }
                    },
            ),
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 14),
          AuthStatusBox(message: errorMessage!),
        ],
        const SizedBox(height: 28),
        GradientActionButton(
          label: loading ? 'Kaydediliyor...' : 'Devam Et',
          onPressed: loading ? null : _completeProfile,
        ),
      ],
    );
  }
}
