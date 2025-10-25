

# Surra | صُرّة
##AI-Powered Personal Finance Management App
###Introduction (Goal)

Surra is a mobile application designed to help individuals in Saudi Arabia manage their spending, track expenses, and strengthen their saving habits.

The goal of the project is to address overspending and limited financial awareness by providing:

- AI-powered insights and personalized financial recommendations.

- Receipt scanning with automatic expense categorization.

- Saving goals with progress tracking and smart alerts.

- Guardian-controlled child accounts that encourage financial literacy among younger users.

- Localized investment features such as gold price prediction to support smarter decision-making.

By integrating artificial intelligence, real-time analytics, and family-oriented budgeting, Surra promotes responsible spending and long-term financial stability across generations.

###Technologies Used

Flutter : Used for developing the cross-platform mobile application.

Dart : Programming language for building the frontend interface and logic.

Supabase : Used for authentication, data storage, and real-time updates (includes PostgreSQL database, Supabase Auth, and Supabase Storage).

Python : Used for building AI and machine learning models.

TensorFlow and scikit-learn : For implementing prediction models and recommendation systems.

Tesseract OCR / Google Vision API : For extracting text from scanned receipts to automatically log expenses.

GitHub : For version control and collaborative development.

Jira : For sprint planning, task tracking, and project management.

###Launch Instructions

1- Clone the Repository
2- Install Dependencies
3-Connect to Supabase
  The project is already linked to the existing Supabase database.
  Ensure the Supabase credentials (supabaseUrl and supabaseAnonKey) are correctly set in the configuration file.
4-Run the Application

The app will automatically connect to the existing Supabase backend, load user data, and enable features such as authentication, category tracking, goal management, and real-time updates.

