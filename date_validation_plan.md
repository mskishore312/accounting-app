# Date Range Selector Validation Plan

**Goal:** Implement date validation in the `DateRangeSelector` to prevent selecting dates before the company's `books_from` date.

## I. Data Access and Preparation (To be done in each UI screen that uses `DateRangeSelector`)

1.  **Fetch Company Data:**
    *   In the `initState` or a similar early lifecycle method of screens like `lib/ui/reports.dart`, `lib/ui/profit_and_loss.dart`, etc.
    *   Call `Map<String, dynamic>? companyData = await StorageService.getSelectedCompany();`
2.  **Extract and Parse `books_from` Date:**
    *   Check if `companyData` is not null and contains the `books_from` key.
    *   `String? booksFromStr = companyData?['books_from'] as String?;`
    *   If `booksFromStr` is not null and not empty:
        *   Parse it using the 'DD/MM/YYYY' format. (We'll need a robust parsing method, possibly using the `intl` package).
          ```dart
          // Example parsing logic (may need intl package for robust parsing)
          DateTime? minDate;
          if (booksFromStr != null && booksFromStr.isNotEmpty) {
            try {
              // Assuming DateFormat from 'package:intl/intl.dart';
              // final format = DateFormat('dd/MM/yyyy');
              // minDate = format.parseStrict(booksFromStr);
              // Fallback manual parsing if intl is not immediately available for planning:
              final parts = booksFromStr.split('/');
              if (parts.length == 3) {
                final day = int.tryParse(parts[0]);
                final month = int.tryParse(parts[1]);
                final year = int.tryParse(parts[2]);
                if (day != null && month != null && year != null) {
                   minDate = DateTime(year, month, day);
                }
              }
            } catch (e) {
              print('Error parsing books_from date: $booksFromStr. Error: $e');
              // Fallback: As per user feedback, company creation should prevent invalid dates.
              // For safety in the picker, if it still occurs, default to a very old date.
              minDate = DateTime(1900, 1, 1);
            }
          } else {
             // If books_from is null or empty, default to a very old date.
             minDate = DateTime(1900, 1, 1);
          }
          ```
    *   Store this parsed `DateTime` object in the state of the UI screen (e.g., `_minSelectableDateForCompany`).
3.  **Pass to `DateRangeSelector`:**
    *   When instantiating `DateRangeSelector`, pass the parsed `_minSelectableDateForCompany` to its `minSelectableDate` property.
      ```dart
      DateRangeSelector(
        initialStartDate: ...,
        initialEndDate: ...,
        onDateRangeSelected: ...,
        minSelectableDate: _minSelectableDateForCompany, // Pass it here
        onCancel: ...,
      )
      ```

## II. Modifications to `DateRangeSelector` (`lib/ui/widgets/date_range_selector.dart`)

1.  **Utilize `widget.minSelectableDate` in `_showSpinnerPicker`:**
    *   The `minSelectableDate` (which will now be the `books_from` date) is already a parameter of `DateRangeSelector` and is passed as `minDate` to `_showSpinnerPicker`.
    *   The year wheel generation at line 145 should correctly limit the minimum year.

2.  **Dynamically Filter Month List:**
    *   Inside `_showSpinnerPicker`'s `StatefulBuilder`.
    *   If `_selectedYear == minDate.year`, the list of months should start from `minDate.month`.
    *   Adjust `_selectedMonth` and `_monthController` if the current selection becomes invalid.

3.  **Dynamically Filter Day List:**
    *   Inside `_showSpinnerPicker`'s `StatefulBuilder`.
    *   If `_selectedYear == minDate.year && _selectedMonth == minDate.month`, the day list should start from `minDate.day`.
    *   Adjust `_selectedDay` and `_dayController` if the current selection becomes invalid.

4.  **Handle Initial Date Coercion in `initState` (Line 52):**
    *   Ensure `initialStartDate` and `initialEndDate` are coerced if they are before `widget.minSelectableDate`.

5.  **Handle Date Coercion in `_selectStartDate` and `_selectEndDate`:**
    *   Ensure `minPickerDate` for `_selectEndDate` is the later of `_currentStartDate` and `widget.minSelectableDate`.
    *   The final check in `_showSpinnerPicker`'s "OK" button (line 179) is crucial.

## III. Visual Representation (Mermaid Diagram)

```mermaid
graph TD
    subgraph UI Screens (e.g., ReportsScreen, DaybookScreen)
        A[initState] -- Fetches company data --> B{StorageService.getSelectedCompany()};
        B -- Returns companyData (Map) --> C[Extract 'books_from'];
        C -- 'DD/MM/YYYY' string --> D[Parse to DateTime object: minCompanyDate];
        D -- minCompanyDate --> E[DateRangeSelector minSelectableDate=minCompanyDate];
    end

    subgraph DateRangeSelector Widget
        F[Widget receives minSelectableDate] --> G[_showSpinnerPicker minDate=minSelectableDate];
        G --> H{Year Spinner};
        H -- Uses minDate.year --> I[Generates Year List];
        G --> J{Month Spinner};
        J -- Uses minDate.month if year matches --> K[Generates Month List];
        G --> L{Day Spinner};
        L -- Uses minDate.day if year & month match --> M[Generates Day List];
        N[User Selects Date] --> O{Validate Selection};
        O -- Against minDate --> P[Return Validated Date or Coerced Date];
    end

    E --> F;