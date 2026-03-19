import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/cart_provider.dart';
import 'providers/theme_provider.dart';
import 'services/chat_notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/search_screen.dart';
import 'screens/cart_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/public_profile_screen.dart';
import 'screens/store_screen.dart';
import 'screens/seller/create_store_screen.dart';
import 'screens/seller/seller_dashboard_screen.dart';
import 'screens/seller/my_products_screen.dart';
import 'screens/seller/add_product_screen.dart';
import 'screens/seller/store_orders_screen.dart';
import 'screens/seller/seller_messages_screen.dart';
import 'screens/seller/seller_reviews_screen.dart';
import 'screens/seller/seller_analytics_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ChatNotificationService.instance.initialize();
  runApp(const AutoMarketApp());
}

class AutoMarketApp extends StatelessWidget {
  const AutoMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    const orange = Color(0xFFF97316);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'AutoMarket DZ',
          debugShowCheckedModeBanner: false,
          themeMode: themeProvider.themeMode,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: orange,
              primary: orange,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
            fontFamily: 'Segoe UI',
            scaffoldBackgroundColor: const Color(0xFFF8FAFC),
            cardColor: Colors.white,
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFF0F172A),
              elevation: 1,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Colors.white,
              selectedItemColor: orange,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: orange,
              primary: orange,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: 'Segoe UI',
            scaffoldBackgroundColor: const Color(0xFF0B1220),
            cardColor: const Color(0xFF111827),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF111827),
              foregroundColor: Color(0xFFF9FAFB),
              elevation: 1,
            ),
            snackBarTheme: const SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFF111827),
              selectedItemColor: orange,
              unselectedItemColor: Color(0xFF9CA3AF),
            ),
          ),
          locale: const Locale('ar'),
          home: const SplashScreen(),
          onGenerateRoute: (settings) {
            // Handle routes with arguments
            if (settings.name == '/public-profile' &&
                settings.arguments is String) {
              return MaterialPageRoute(
                builder: (context) =>
                    PublicProfileScreen(userId: settings.arguments as String),
              );
            }
            if (settings.name == '/store' && settings.arguments is String) {
              return MaterialPageRoute(
                builder: (context) =>
                    StoreScreen(storeId: settings.arguments as String),
              );
            }
            // Default routes
            return null;
          },
          routes: {
            '/home': (_) => const HomeScreen(),
            '/login': (_) => const LoginScreen(),
            '/register': (_) => const RegisterScreen(),
            '/search': (_) => const SearchScreen(),
            '/cart': (_) => const CartScreen(),
            '/orders': (_) => const OrdersScreen(),
            '/profile': (_) => const ProfileScreen(),
            '/create-store': (_) => const CreateStoreScreen(),
            '/seller-dashboard': (_) => const SellerDashboardScreen(),
            '/seller-products': (_) => const MyProductsScreen(),
            '/seller-add-product': (_) => const AddProductScreen(),
            '/seller-orders': (_) => const StoreOrdersScreen(),
            '/seller-messages': (_) => const SellerMessagesScreen(),
            '/seller-reviews': (_) => const SellerReviewsScreen(),
            '/seller-analytics': (_) => const SellerAnalyticsScreen(),
          },
        ),
      ),
    );
  }
}
