import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import '../../api/dio_client.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../core/bento_colors.dart';
import '../../widgets/bento_input.dart';
import '../../widgets/bento_button.dart';
import '../../repositories/user_repository.dart';
import '../../widgets/bento_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  late final UserRepository _userRepository;
  bool _isLoading = false;
  bool _isSaving = false;

  String? _avatarUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _userRepository = UserRepository(apiClient: ApiClient());
    _loadUserInfo();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    setState(() => _isLoading = true);

    try {
      final user = await _userRepository.getCurrentUser();
      _nameController.text = user.name;
      _phoneController.text = user.phone ?? '';
      _emailController.text = user.email ?? '';
      _avatarUrl = user.avatar;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载用户信息失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    try {
      final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery, maxWidth: 1024, maxHeight: 1024);
      if (image == null) return;

      setState(() => _isLoading = true);

      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(image.path, filename: image.name),
      });

      final response =
          await ApiClient().dio.post('/upload/photo', data: formData);
      if (response.statusCode == 200 && response.data['code'] == 200) {
        final uploadedUrl = response.data['data']?['url']?.toString();
        setState(() {
          _avatarUrl = ApiClient.resolveFileUrl(uploadedUrl);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('头像上传成功，请点击保存生效')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('头像上传失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final updatedUser = await _userRepository.updateProfile(
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty
            ? null
            : _emailController.text.trim(),
        avatar: _avatarUrl,
      );

      if (mounted) {
        context.read<AuthBloc>().add(UserUpdated(user: updatedUser));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('个人信息更新成功')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: Text(
          '编辑个人信息',
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                if (state is! AuthAuthenticated) {
                  return const SizedBox();
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        Center(
                          child: GestureDetector(
                            onTap: _pickAndUploadAvatar,
                            child: Stack(
                              children: [
                                BentoAvatar.large(
                                  imageUrl: _avatarUrl ?? state.user.avatar,
                                  text: state.user.name,
                                  backgroundColor: colors.primaryLight,
                                  textColor: colors.primary,
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: colors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        BentoInput(
                          label: '姓名/昵称',
                          controller: _nameController,
                          prefixIcon: const Icon(Icons.person),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return '请输入姓名';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        BentoInput(
                          label: '手机号',
                          controller: _phoneController,
                          prefixIcon: const Icon(Icons.phone),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) {
                                return '请输入正确的手机号';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        BentoInput(
                          label: '邮箱',
                          controller: _emailController,
                          prefixIcon: const Icon(Icons.email),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return '请输入正确的邮箱地址';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 32),
                        BentoButton.primary(
                          text: '保存',
                          loading: _isSaving,
                          onPressed: _isSaving ? null : _saveProfile,
                          size: BentoButtonSize.large,
                          fullWidth: true,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}
