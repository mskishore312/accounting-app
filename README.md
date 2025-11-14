# accounting_app

Accounting App Architecture Plan
================================

Overview
--------
This app is a Flutter-based accounting solution designed to support multiple accounting reports, including financial statements, daybook, cashbook, ledger reports, and more. The app integrates UI designs reflected in the Dart files with a robust data management layer utilizing a local SQLite database.

Architecture Layers
-------------------
1. UI Layer
   - **Screens & Widgets:**  
     • Account master, Ledger view, Daybook, Reports, Vouchers, etc.  
     • UI designs stored in the "UI Designs" folder guide the layout and user experience.
   - **Navigation:**  
     • Utilizes Flutter Navigator for screen transitions.
   - **Theming & Styling:**  
     • Consistent across modules based on provided designs.
   
2. Data Models
   - Models (e.g., Account, Transaction, Report) define the core business entities.
   - These models include conversion methods (fromMap, toMap) for database operations.
   
3. Data Persistence Layer
   - **Storage Service:**  
     • Implements local database access using the sqflite package.  
     • Provides CRUD operations for tables such as "accounts" and "transactions."
   - **Database Schema:**  
     • Defined in StorageService _createDB method.
     • Tables are set up with appropriate relationships (e.g., transactions referencing accounts).
   
4. Business Logic Layer
   - **Report Service:**  
     • Contains logic to generate various accounting reports:  
       - Financial Statements (aggregated totals, balances, assets, liabilities)  
       - Daybook (daily transaction logs)  
       - Cashbook (cash transaction summaries)  
       - Ledger Reports (detailed transaction ledgers)
   - **Other Services & Managers:**  
     • LedgerManager, JournalVoucher, PaymentVoucher, and ReceiptVoucher modules handle accounting transactions and validations.
   
5. Integration & Future Enhancements
   - Potential to integrate remote data services (via MCP servers or REST APIs) for multi-device synchronization.
   - Additional modules may include audit logs and compliance reporting.
   
Overall Flow
------------
1. **User Interaction:**  
   The user interacts with the UI based on provided designs.
2. **Data Operations:**  
   User actions trigger StorageService methods for data retrieval and persistence.
3. **Reporting:**  
   ReportService aggregates data from models and produces structured reports.
4. **Display:**  
   Generated reports are formatted and displayed in dedicated UI screens.

Conclusion
----------
The architecture balances a clean separation between UI presentation, data management, and business logic. This modular approach ensures scalability, testability, and ease of maintenance, while aligning with the provided UI designs and reporting requirements.

