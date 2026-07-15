// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../models/loan_model.dart';
import '../models/payment_schedule_model.dart';

class ContractPdfService {
  static final _dateFmt = DateFormat('dd/MM/yyyy');
  static final _currFmt = NumberFormat.currency(symbol: '€', decimalDigits: 2);

  /// Generate and download a loan contract PDF
  static Future<void> downloadContract(
    LoanModel loan,
    PaymentSchedule? schedule,
  ) async {
    final pdf = pw.Document();
    final totalDu = loan.montant + loan.coutTotalEstime;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          pw.Center(
            child: pw.Text(
              'CONTRAT DE PRÊT ENTRE PARTICULIERS',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              'Référence : ${loan.id}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
          pw.SizedBox(height: 6),
          pw.Center(
            child: pw.Text(
              'Date d\'émission : ${_dateFmt.format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
          pw.Divider(thickness: 1.5),
          pw.SizedBox(height: 12),

          // Borrower info
          _sectionTitle('1. EMPRUNTEUR'),
          _infoRow('Nom', loan.nomEmprunteur),
          _infoRow(
            'RIB / IBAN',
            loan.ribEmprunteur.isNotEmpty
                ? loan.ribEmprunteur
                : 'Non renseigné',
          ),
          pw.SizedBox(height: 16),

          // Loan terms
          _sectionTitle('2. CONDITIONS DU PRÊT'),
          _infoRow('Montant emprunté', _currFmt.format(loan.montant)),
          _infoRow('Taux effectif', '${loan.tauxAnnuel.toStringAsFixed(2)}%'),
          _infoRow('Durée', '${loan.dureeMois} mois'),
          _infoRow('Mensualité', _currFmt.format(loan.mensualite)),
          _infoRow(
            'Coût total des intérêts',
            _currFmt.format(loan.coutTotalEstime),
          ),
          _infoRow('Total à rembourser', _currFmt.format(totalDu)),
          pw.SizedBox(height: 4),
          _infoRow('Date de création', _dateFmt.format(loan.createdAt)),
          if (loan.approvedAt != null)
            _infoRow('Date d\'approbation', _dateFmt.format(loan.approvedAt!)),
          if (loan.disbursedAt != null)
            _infoRow(
              'Date de décaissement',
              _dateFmt.format(loan.disbursedAt!),
            ),
          _infoRow(
            'Premier remboursement',
            _dateFmt.format(loan.datePremierRemboursement),
          ),
          pw.SizedBox(height: 16),

          // Schedule table
          if (schedule != null && schedule.echeances.isNotEmpty) ...[
            _sectionTitle('3. ÉCHÉANCIER DE REMBOURSEMENT'),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headerStyle: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey200,
              ),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.center,
                2: pw.Alignment.centerRight,
                3: pw.Alignment.centerRight,
                4: pw.Alignment.centerRight,
                5: pw.Alignment.center,
              },
              headers: [
                'N°',
                'Échéance',
                'Capital',
                'Intérêts',
                'Total',
                'Statut',
              ],
              data: schedule.echeances
                  .map(
                    (e) => [
                      '${e.numeroEcheance}',
                      _dateFmt.format(e.dateEcheance),
                      _currFmt.format(e.montantCapital),
                      _currFmt.format(e.montantInterets),
                      _currFmt.format(e.montantTotal),
                      e.isPaid
                          ? 'Payé'
                          : (e.isOverdue ? 'En retard' : 'À venir'),
                    ],
                  )
                  .toList(),
            ),
            pw.SizedBox(height: 16),
          ],

          // Terms
          _sectionTitle(
            schedule != null
                ? '4. CONDITIONS GÉNÉRALES'
                : '3. CONDITIONS GÉNÉRALES',
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Ce document récapitule les conditions du prêt consenti entre particuliers '
            'via la plateforme Chafin Loans. L\'emprunteur s\'engage à rembourser '
            'les mensualités aux dates prévues dans l\'échéancier ci-dessus. '
            'Tout retard de paiement pourra donner lieu à des pénalités.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'En cas de remboursement anticipé, les intérêts sont recalculés '
            'au prorata de la durée effective du prêt.',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 24),

          // Signatures
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Le prêteur',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Container(width: 150, child: pw.Divider()),
                  pw.Text(
                    'Signature',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'L\'emprunteur',
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Container(width: 150, child: pw.Divider()),
                  pw.Text(
                    'Signature',
                    style: const pw.TextStyle(
                      fontSize: 9,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
        footer: (context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Chafin Loans — Page ${context.pageNumber}/${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ),
      ),
    );

    final Uint8List bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'contrat_${loan.id}.pdf')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.blue900,
        ),
      ),
    );
  }

  static pw.Widget _infoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 180,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
