import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';

String? _firebaseAuthErrorMessage(FirebaseAuthException e) {
  switch (e.code) {
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Invalid email or password';
    case 'invalid-email':
      return 'Please enter a valid email address';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later';
    case 'user-disabled':
      return 'This account has been disabled';
    case 'email-already-in-use':
      return 'Registration failed';
    case 'weak-password':
      return 'Password must be at least 8 characters with uppercase, lowercase, and a number';
    default:
      return null;
  }
}

String _sanitize(String input) {
  return input.trim().replaceAll(RegExp(r'<[^>]*>'), '');
}

String _safeSubstring(String input, int maxLength) {
  if (input.length <= maxLength) return input;
  return input.substring(0, maxLength);
}

bool _isValidPassword(String value) {
  if (value.length < 8) return false;
  if (!value.contains(RegExp(r'[A-Z]'))) return false;
  if (!value.contains(RegExp(r'[a-z]'))) return false;
  if (!value.contains(RegExp(r'[0-9]'))) return false;
  return true;
}

Future<bool> _isAdminUser() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;
  try {
    final doc = await FirebaseFirestore.instance.collection('admins').doc(user.uid).get();
    return doc.exists;
  } catch (_) {
    return false;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate();
  runApp(const ShoppingApp());
}

class ShoppingApp extends StatelessWidget {
  const ShoppingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shopping App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SignInPage(),
    );
  }
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      _passwordController.clear();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_firebaseAuthErrorMessage(e) ?? 'Sign in failed')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator:
                            (value) =>
                                value == null || !value.contains('@')
                                    ? 'Enter a valid email'
                                    : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (value) =>
                                value == null || !_isValidPassword(value)
                                    ? 'Min 8 chars, upper, lower, number'
                                    : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _signIn,
                          child:
                              _loading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Sign In'),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterPage(),
                            ),
                          );
                        },
                        child: const Text('Create account'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      await credential.user?.sendEmailVerification();
      _passwordController.clear();
      _confirmController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created! Check your email to verify your address.',
          ),
        ),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SignInPage()),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(_firebaseAuthErrorMessage(e) ?? 'Registration failed'),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              elevation: 8,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator:
                            (value) =>
                                value == null || !value.contains('@')
                                    ? 'Enter a valid email'
                                    : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (value) =>
                                value == null || !_isValidPassword(value)
                                    ? 'Min 8 chars, upper, lower, number'
                                    : null,
                      ),
                      const SizedBox(height: 15),
                      TextFormField(
                        controller: _confirmController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: Icon(Icons.lock_outline),
                          border: OutlineInputBorder(),
                        ),
                        validator:
                            (value) =>
                                value != _passwordController.text
                                    ? 'Passwords do not match'
                                    : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _register,
                          child:
                              _loading
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Create Account'),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Already have an account? Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final List<Product> _cartItems = [];

  void _addToCart(Product product) {
    setState(() {
      _cartItems.add(product);
    });
  }

  void _clearCart() {
    setState(() {
      _cartItems.clear();
    });
  }

  double _calculateTotal() =>
      _cartItems.fold(0, (total, item) => total + item.price);

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SignInPage()),
    );
  }

  void _showCartDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Shopping Cart'),
            content:
                _cartItems.isEmpty
                    ? const Text('Your cart is empty')
                    : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ..._cartItems.map(
                          (item) => ListTile(
                            leading: Image.network(
                              item.image,
                              width: 40,
                              height: 40,
                            ),
                            title: Text(item.name),
                            subtitle: Text(
                              '\$${item.price.toStringAsFixed(2)}',
                            ),
                          ),
                        ),
                        const Divider(),
                        Text(
                          'Total: \$${_calculateTotal().toStringAsFixed(2)}',
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Close'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                showDialog(
                                  context: context,
                                  builder:
                                      (_) => AlertDialog(
                                        title:
                                            const Text('Confirm Purchase'),
                                        content: Text(
                                          'Proceed with payment of \$${_calculateTotal().toStringAsFixed(2)}?',
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed:
                                                () => Navigator.pop(context),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () {
                                              _clearCart();
                                              Navigator.pop(context);
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Order placed successfully!',
                                                  ),
                                                ),
                                              );
                                            },
                                            child: const Text('Confirm'),
                                          ),
                                        ],
                                      ),
                                );
                              },
                              child: const Text('Checkout'),
                            ),
                          ],
                        ),
                      ],
                    ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shopping App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign out',
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutPage()),
            ),
            tooltip: 'About',
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () async {
              if (FirebaseAuth.instance.currentUser == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please sign in to access admin panel'),
                  ),
                );
                return;
              }
              final admin = await _isAdminUser();
              if (!mounted) return;
              if (!admin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Admin access required'),
                  ),
                );
                return;
              }
              if (!mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminPanel()),
              );
            },
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.shopping_cart),
                onPressed: () => _showCartDialog(context),
              ),
              if (_cartItems.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: CircleAvatar(
                    radius: 10,
                    child: Text(_cartItems.length.toString()),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const _BannerSection(),
          Expanded(
            child: ProductCatalog(onAddToCart: _addToCart),
          ),
        ],
      ),
    );
  }
}

class Product {
  final String name;
  final String image;
  final String description;
  final double price;

  Product({
    required this.name,
    required this.image,
    required this.price,
    required this.description,
  });
}

class _BannerSection extends StatelessWidget {
  const _BannerSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.blue, Colors.purple]),
        borderRadius: BorderRadius.circular(15),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Eid Mubarak!',
              style: TextStyle(fontSize: 32, color: Colors.white),
            ),
            Text(
              'Up to 50% off',
              style: TextStyle(fontSize: 18, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductCatalog extends StatelessWidget {
  final void Function(Product) onAddToCart;

  const ProductCatalog({super.key, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('products')
              .orderBy('createdAt', descending: true)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Error loading products'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final products =
            snapshot.data!.docs.map((doc) {
              final data = doc.data()! as Map<String, dynamic>;
              return Product(
                name: data['name'] ?? 'Unnamed',
                image: data['image'] ?? '',
                price: (data['price'] as num?)?.toDouble() ?? 0.0,
                description: data['description'] ?? '',
              );
            }).toList();

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 0.7,
          ),
          itemCount: products.length,
          itemBuilder:
              (context, index) => _ProductItem(
                product: products[index],
                onAddToCart: onAddToCart,
              ),
        );
      },
    );
  }
}

class _ProductItem extends StatelessWidget {
  final Product product;
  final void Function(Product) onAddToCart;

  const _ProductItem({required this.product, required this.onAddToCart});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap:
          () => Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => ProductDetails(
                    product: product,
                    onAddToCart: onAddToCart,
                  ),
            ),
          ),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(15),
                ),
                child: Image.network(
                  product.image,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder:
                      (_, __, ___) => const Center(child: Icon(Icons.error)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ProductDetails extends StatelessWidget {
  final Product product;
  final void Function(Product) onAddToCart;

  const ProductDetails({
    super.key,
    required this.product,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Image.network(
              product.image,
              height: 300,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 24, color: Colors.green),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(product.description),
                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Add to Cart'),
                      onPressed: () {
                        onAddToCart(product);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added ${product.name} to cart'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Icon(Icons.shopping_bag, size: 80, color: Theme.of(context).primaryColor),
                  const SizedBox(height: 12),
                  const Text(
                    'Shopping App',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'About',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Shopping App is a modern e-commerce mobile application built with Flutter and Firebase. '
              'It provides a seamless shopping experience with real-time product listings, '
              'user authentication, and a built-in shopping cart.',
              style: TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Features',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _featureItem(Icons.lock, 'Secure authentication with Firebase Auth'),
            _featureItem(Icons.shopping_cart, 'Add products to cart and checkout'),
            _featureItem(Icons.grid_view, 'Browse products in a grid catalog'),
            _featureItem(Icons.admin_panel_settings, 'Admin panel for product management'),
            _featureItem(Icons.security, 'App Check & Firestore security rules'),
            _featureItem(Icons.verified_user, 'Email verification for new accounts'),
            const SizedBox(height: 24),
            const Text(
              'Tech Stack',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Flutter & Dart\n'
              '• Firebase Authentication\n'
              '• Cloud Firestore (NoSQL database)\n'
              '• Firebase App Check\n'
              '• Material Design',
              style: TextStyle(fontSize: 15, height: 1.6),
            ),
            const SizedBox(height: 32),
            Center(
              child: Text(
                'Made with Flutter',
                style: TextStyle(color: Colors.grey[500], fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _featureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 22, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}

class AdminPanel extends StatefulWidget {
  const AdminPanel({super.key});

  @override
  State<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanel> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _imageController = TextEditingController();
  final _descController = TextEditingController();
  bool _creating = false;
  bool _isAdmin = false;
  bool _adminCheckDone = false;
  DateTime _lastCreate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final admin = await _isAdminUser();
    if (!mounted) return;
    setState(() {
      _isAdmin = admin;
      _adminCheckDone = true;
    });
    if (!admin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin access required')),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _imageController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _createProduct() async {
    if (!_formKey.currentState!.validate()) return;

    if (DateTime.now().difference(_lastCreate).inSeconds < 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait before creating another product')),
      );
      return;
    }

    final admin = await _isAdminUser();
    if (!admin) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin access required')),
      );
      return;
    }

    setState(() => _creating = true);
    try {
      final price = double.tryParse(_priceController.text);
      if (price == null || price <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid positive price')),
        );
        return;
      }
      final imageUrl = _sanitize(_imageController.text);
      if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image URL must start with http:// or https://')),
        );
        return;
      }
      _lastCreate = DateTime.now();
      await FirebaseFirestore.instance.collection('products').add({
        'name': _safeSubstring(_sanitize(_nameController.text), 100),
        'price': price,
        'image': imageUrl,
        'description': _safeSubstring(_sanitize(_descController.text), 1000),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _nameController.clear();
      _priceController.clear();
      _imageController.clear();
      _descController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product created successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create product: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _deleteProduct(String docId) async {
    try {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Delete Product'),
              content: const Text(
                'Are you sure you want to delete this product?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
      );

      if (confirm == true) {
        await FirebaseFirestore.instance
            .collection('products')
            .doc(docId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product deleted successfully')),
          );
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Delete error: $e\n$stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Panel')),
      body: !_adminCheckDone
          ? const Center(child: CircularProgressIndicator())
          : !_isAdmin
              ? const Center(child: Text('Access denied'))
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('New Product', style: TextStyle(fontSize: 24)),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Product Name',
                    ),
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'Required'
                                : null,
                  ),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Price'),
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'Required'
                                : null,
                  ),
                  TextFormField(
                    controller: _imageController,
                    decoration: const InputDecoration(labelText: 'Image URL'),
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'Required'
                                : null,
                  ),
                  TextFormField(
                    controller: _descController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'Required'
                                : null,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _creating ? null : _createProduct,
                    child:
                        _creating
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Create Product'),
                  ),
                  const Divider(height: 40),
                  const Text(
                    'Existing Products',
                    style: TextStyle(fontSize: 24),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance
                        .collection('products')
                        .orderBy('createdAt', descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Error loading products'));
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final docs = snapshot.data!.docs;
                  if (docs.isEmpty) {
                    return const Center(child: Text('No products found'));
                  }
                  return ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final doc = docs[index];
                      final data = doc.data()! as Map<String, dynamic>;
                      return ListTile(
                        leading: Image.network(
                          data['image'] ?? '',
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder:
                              (_, __, ___) => const Icon(Icons.error),
                        ),
                        title: Text(data['name'] ?? 'Unnamed'),
                        subtitle: Text(
                          '\$${(data['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteProduct(doc.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
