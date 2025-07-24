# MilkTrack

MilkTrack is a professional Flutter application designed for dairy farms to efficiently track milk production, manage sales, record expenses, and handle customer data. The app is built with Firebase for secure authentication and real-time data storage, and features a modern, responsive UI.

## Features

### 🥛 Milk Production Tracking
- Record daily milk production for each cow.
- Track production by date, session (morning/evening), and quantity.
- Admins can view all records; staff see only their own.
- Edit or delete production records.
- Export selected records as PDF for reporting.

### 💸 Sales Management
- Record sales transactions with customer details.
- Track liters sold, price per liter, and total sales.
- Associate sales with registered customers.
- View sales history.

### 📋 Expense Tracking
- Add and manage expenses with amount, reason, and date.
- Filter expenses by reason for easy analysis.
- View a list of all expenses, with real-time updates.

### 👥 Customer Management
- Add new customers with name, phone, address, and milk price.
- Ensure unique customer IDs.
- Manage and update customer information.

### ⚙️ Settings & Customization
- Toggle between light and dark mode.
- View app version and developer info.

### 🔒 Authentication & Security
- Secure login with phone number and password (mapped to email in Firebase).
- User roles: admin and staff, with different permissions.

### 📱 Modern Flutter UI
- Responsive design for mobile and web.
- Uses Google Fonts, animated backgrounds, and modern card layouts.
- Theming support with light/dark mode.

## Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- Firebase project (see `lib/firebase_options.dart` for setup)
- Android Studio or Xcode for mobile builds

### Installation

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd milktrack
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase:**
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) to the respective directories.
   - Update `lib/firebase_options.dart` if needed.

4. **Run the app:**
   ```bash
   flutter run
   ```

## Project Structure

- `lib/`
  - `main.dart` – App entry point and theme setup
  - `home_page.dart` – Dashboard with navigation
  - `login_page.dart`, `register_page.dart` – Authentication
  - `pages/`
    - `production_list_page.dart` – Milk production records
    - `milk_production_page.dart` – Add/edit production
    - `sales_page.dart` – Sales management
    - `expenses_page.dart` – Expense tracking and filtering
    - `add_customer_page.dart` – Customer management
    - `settings_page.dart` – App settings

- `assets/images/` – App images and icons

## Dependencies

- `firebase_core`, `firebase_auth`, `cloud_firestore` – Firebase integration
- `google_fonts`, `animate_do`, `flutter_animate`, `lottie` – UI/UX enhancements
- `pdf`, `printing` – PDF export
- `shared_preferences` – Local storage for settings

## Contributing

Pull requests are welcome! For major changes, please open an issue first to discuss what you would like to change.

## License

This project is private and not published on pub.dev.
