const ReportsHook = {
    mounted() {
        // Handle file downloads
        console.log('sssssssssssssssssssssss')
        this.handleEvent("download_file", ({ data, filename, mime_type }) => {
            const blob = new Blob([data], { type: mime_type });
            const url = window.URL.createObjectURL(blob);
            const a = document.createElement('a');
            a.href = url;
            a.download = filename;
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            window.URL.revokeObjectURL(url);
        });

        // Handle PDF export (print to PDF)
        this.handleEvent("export_pdf", ({ title, date_range }) => {
            // Set document title for PDF
            const originalTitle = document.title;
            document.title = `${title} - ${date_range}`;

            // Add print-specific styles
            this.addPrintStyles();

            // Trigger browser print dialog
            setTimeout(() => {
                window.print();

                // Restore original title
                document.title = originalTitle;

                // Remove print styles after print dialog closes
                setTimeout(() => {
                    this.removePrintStyles();
                }, 1000);
            }, 100);
        });

        // Handle regular print
        this.handleEvent("print_report", () => {
            this.addPrintStyles();
            window.print();
            setTimeout(() => {
                this.removePrintStyles();
            }, 1000);
        });
    },

    addPrintStyles() {
        if (!this.printStyleSheet) {
            this.printStyleSheet = document.createElement('style');
            this.printStyleSheet.id = 'reports-print-styles';
            this.printStyleSheet.textContent = `
        @media print {
          @page {
            margin: 0.75in;
            size: A4;
          }
          
          /* Hide unnecessary elements */
          .print\\:hidden,
          button:not(.print\\:show),
          .hover\\:shadow-xl,
          .hover\\:bg-gray-50,
          .transition-all,
          .transition-colors,
          .transition-shadow,
          nav,
          .side-nav,
          .export-controls,
          .dropdown,
          .tooltip {
            display: none !important;
          }
          
          /* Reset backgrounds and colors for print */
          .bg-gradient-to-r,
          .bg-gradient-to-br,
          .bg-gradient-to-t,
          .bg-slate-800,
          .bg-slate-700,
          .bg-indigo-600,
          .bg-purple-600,
          .bg-blue-600 {
            background: white !important;
            color: black !important;
          }
          
          .text-white {
            color: black !important;
          }
          
          .text-slate-200,
          .text-indigo-100 {
            color: #666 !important;
          }
          
          /* Ensure charts are visible in black and white */
          .bg-emerald-500,
          .bg-emerald-400 {
            background-color: #059669 !important;
          }
          
          .bg-blue-500,
          .bg-blue-400 {
            background-color: #3b82f6 !important;
          }
          
          .bg-amber-500,
          .bg-amber-400 {
            background-color: #f59e0b !important;
          }
          
          .bg-red-500,
          .bg-red-400 {
            background-color: #ef4444 !important;
          }
          
          .bg-purple-500,
          .bg-purple-400 {
            background-color: #8b5cf6 !important;
          }
          
          .bg-indigo-500,
          .bg-indigo-400 {
            background-color: #6366f1 !important;
          }
          
          /* Optimize shadows and borders */
          .shadow-lg,
          .shadow-xl,
          .shadow-md {
            box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1) !important;
          }
          
          .rounded-2xl,
          .rounded-xl {
            border-radius: 8px !important;
          }
          
          /* Ensure proper spacing */
          .space-y-8 > * + * {
            margin-top: 1rem !important;
          }
          
          .space-y-6 > * + * {
            margin-top: 0.75rem !important;
          }
          
          /* Optimize table printing */
          table {
            page-break-inside: auto;
          }
          
          tr {
            page-break-inside: avoid;
            page-break-after: auto;
          }
          
          thead {
            display: table-header-group;
          }
          
          tfoot {
            display: table-footer-group;
          }
          
          /* Ensure charts don't break across pages */
          .chart-container,
          .bg-white.rounded-2xl {
            page-break-inside: avoid;
          }
          
          /* Header styling for print */
          .print-header {
            border-bottom: 2px solid #000;
            margin-bottom: 1rem;
            padding-bottom: 0.5rem;
          }
          
          /* Footer for print */
          .print-footer {
            position: fixed;
            bottom: 0;
            left: 0;
            right: 0;
            text-align: center;
            font-size: 10px;
            color: #666;
            border-top: 1px solid #ccc;
            padding-top: 0.25rem;
          }
        }
      `;
            document.head.appendChild(this.printStyleSheet);
        }
    },

    removePrintStyles() {
        if (this.printStyleSheet) {
            document.head.removeChild(this.printStyleSheet);
            this.printStyleSheet = null;
        }
    },

    destroyed() {
        this.removePrintStyles();
    }
};

export default ReportsHook;
