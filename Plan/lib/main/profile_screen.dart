import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../screens/login_screen.dart';
import '../user_data/user_info_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final String placeholderImageUrl = "https://via.placeholder.com/150";
  String? profileImageUrl;
  List<String> additionalPhotos = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileImage();
    _fetchAdditionalPhotos();
  }

  Future<void> _fetchProfileImage() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        profileImageUrl = doc.data()?['photoUrl'] ?? placeholderImageUrl;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar la foto de perfil: $e')),
      );
    }
  }

  Future<void> _fetchAdditionalPhotos() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final photos = doc.data()?['additionalPhotos'] as List<dynamic>?;

      setState(() {
        additionalPhotos = photos?.cast<String>() ?? [];
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar las fotos adicionales: $e')),
      );
    }
  }

  Future<void> _pickMultipleImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          _isLoading = true;
        });

        for (var file in result.files) {
          if (file.path != null) {
            await _uploadAndAddImage(File(file.path!));
          }
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imágenes: $e')),
      );
    }
  }

  Future<void> _uploadAndAddImage(File image) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ref = FirebaseStorage.instance
          .ref()
          .child('user_photos')
          .child('${user.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putFile(image);

      final imageUrl = await ref.getDownloadURL();
      setState(() {
        additionalPhotos.add(imageUrl);
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'additionalPhotos': additionalPhotos});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir la imagen: $e')),
      );
    }
  }

  Future<void> _setAsProfilePhoto(String imageUrl) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'photoUrl': imageUrl});
      setState(() {
        profileImageUrl = imageUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar la foto de perfil: $e')),
      );
    }
  }

  Future<void> _deletePhoto(String imageUrl) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final ref = FirebaseStorage.instance.refFromURL(imageUrl);
      await ref.delete();

      setState(() {
        additionalPhotos.remove(imageUrl);
      });

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'additionalPhotos': additionalPhotos});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imagen eliminada')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar la foto: $e')),
      );
    }
  }

  void _openPhotoViewer(int initialIndex) {
    PageController controller = PageController(initialPage: initialIndex);
    int currentPage = initialIndex;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.white,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: controller,
                    onPageChanged: (index) {
                      setState(() {
                        currentPage = index;
                      });
                    },
                    itemCount: additionalPhotos.length,
                    itemBuilder: (context, index) {
                      final imageUrl = additionalPhotos[index];

                      return Container(
                        color: Colors.white,
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 16,
                    right: 16,
                    child: PopupMenuButton<String>(
                      onSelected: (value) async {
                        final currentPhoto = additionalPhotos[currentPage];
                        if (value == 'set_as_profile') {
                          await _setAsProfilePhoto(currentPhoto);
                        } else if (value == 'delete') {
                          await _deletePhoto(currentPhoto);
                          Navigator.of(context).pop();
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'set_as_profile',
                          child: Text('Establecer como foto de perfil'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('Eliminar imagen'),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 32,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        '${currentPage + 1}/${additionalPhotos.length}',
                        style: TextStyle(fontSize: 32, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Yo'),
        backgroundColor: Colors.purple,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: Colors.amber[50],
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(profileImageUrl ?? placeholderImageUrl),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('users')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .get(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Text(
                                  'Cargando...',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                );
                              }

                              if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
                                return Text(
                                  'Error al cargar',
                                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                );
                              }

                              final userData = snapshot.data?.data() as Map<String, dynamic>?;
                              final userName = userData?['name'] ?? 'Usuario';
                              final userAge = userData?['age']?.toString() ?? '';

                              return Text(
                                '$userName, $userAge',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: [
                                GestureDetector(
                                  onTap: _pickMultipleImages,
                                  child: Container(
                                    height: 80,
                                    width: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.grey),
                                      color: Colors.grey[200],
                                    ),
                                    child: Icon(Icons.add, color: Colors.grey),
                                  ),
                                ),
                                ...additionalPhotos.map((url) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      url,
                                      height: 80,
                                      width: 80,
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 16),
                        ListTile(
                          leading: Icon(Icons.info, color: Colors.grey[700]),
                          title: Text('Tu información'),
                          trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                          onTap: () async {
                            final isUpdated = await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => UserInfoScreen()),
                            );

                            if (isUpdated == true) {
                              setState(() {
                                _fetchProfileImage();
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: GestureDetector(
                    onTap: () async {
                      await FirebaseAuth.instance.signOut();
                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => LoginScreen()),
                      );
                    },
                    child: Center(
                      child: Text(
                        'Cerrar sesión',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
