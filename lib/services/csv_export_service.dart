// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../models/loan_model.dart';
import '../models/schedule_item_model.dart';

class CsvExportService {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  /// Export loans to CSV and trigger browser download
  static void exportLoans(List<LoanModel> loans) {
    final buf = StringBuffer();
    buf.writeln(
      'ID,Emprunteur,UserId,Montant,Taux,Durée (mois),Mensualité,Statut,Créé le,RIB',
    );
    for (final l in loans) {
      buf.writeln(
        [
          _esc(l.id),
          _esc(l.nomEmprunteur),
          _esc(l.userId),
          l.montant.toStringAsFixed(2),
          l.tauxAnnuel.toStringAsFixed(2),
          l.dureeMois,
          l.mensualite.toStringAsFixed(2),
          l.statut.name,
          _dateFmt.format(l.createdAt),
          _esc(l.ribEmprunteur),
        ].join(','),
      );
    }
    _download(
      buf.toString(),
      'chafin_prets_${_dateFmt.format(DateTime.now()).replaceAll('/', '-')}.csv',
    );
  }

  /// Export schedule items to CSV
  static void exportSchedules(List<ScheduleItemModel> schedules) {
    final buf = StringBuffer();
    buf.writeln(
      'Prêt ID,Numéro,Échéance,Principal,Intérêts,Total,Pénalité,Payé,Date paiement',
    );
    for (final s in schedules) {
      buf.writeln(
        [
          _esc(s.loanId),
          s.numero,
          _dateFmt.format(s.dueDate),
          s.principal.toStringAsFixed(2),
          s.interet.toStringAsFixed(2),
          s.total.toStringAsFixed(2),
          (s.penaltyAmount ?? 0).toStringAsFixed(2),
          s.isPaid ? 'Oui' : 'Non',
          s.paidAt != null ? _dateFmt.format(s.paidAt!) : '',
        ].join(','),
      );
    }
    _download(
      buf.toString(),
      'chafin_echeancier_${_dateFmt.format(DateTime.now()).replaceAll('/', '-')}.csv',
    );
  }

  /// Export overdue summary
  static void exportOverdue(
    List<LoanModel> loans,
    List<ScheduleItemModel> schedules,
  ) {
    final now = DateTime.now();
    final overdue = loans
        .where((l) => l.statut == LoanStatus.enRetard)
        .toList();
    final buf = StringBuffer();
    buf.writeln(
      'Emprunteur,Montant prêt,Éch. impayées,Montant impayé,Jours retard',
    );
    for (final loan in overdue) {
      final unpaid =
          schedules
              .where(
                (s) =>
                    s.loanId == loan.id && !s.isPaid && s.dueDate.isBefore(now),
              )
              .toList()
            ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
      if (unpaid.isEmpty) continue;
      final daysLate = now.difference(unpaid.first.dueDate).inDays;
      final unpaidTotal = unpaid.fold<double>(0, (s, e) => s + e.total);
      buf.writeln(
        [
          _esc(loan.nomEmprunteur),
          loan.montant.toStringAsFixed(2),
          unpaid.length,
          unpaidTotal.toStringAsFixed(2),
          daysLate,
        ].join(','),
      );
    }
    _download(
      buf.toString(),
      'chafin_recouvrement_${_dateFmt.format(DateTime.now()).replaceAll('/', '-')}.csv',
    );
  }

  static String _esc(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }

  static void _download(String csv, String filename) {
    // Add BOM for Excel UTF-8 compatibility
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode(csv)];
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
