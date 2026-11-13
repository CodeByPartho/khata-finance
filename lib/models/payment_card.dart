import '../logic/card_cycle.dart';

/// A bank card or credit card with a billing cycle. [billingStartDay]
/// is the day of the month a cycle starts (1-31), [dueDay] is the
/// day of the following month payment is due. [accountId] links the
/// card to one wallet for cycle spend; empty means all accounts.
class PaymentCard {
  final String id;
  final String name;
  final bool isCredit;
  final int billingStartDay;
  final int dueDay;
  final String accountId;

  const PaymentCard({
    required this.id,
    required this.name,
    this.isCredit = true,
    required this.billingStartDay,
    required this.dueDay,
    this.accountId = '',
  });

  CardCycle get cycle =>
      CardCycle(billingStartDay: billingStartDay, dueDay: dueDay);

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'isCredit': isCredit,
      'billingStartDay': billingStartDay,
      'dueDay': dueDay,
      'accountId': accountId,
    };
  }

  factory PaymentCard.fromJson(Map<String, dynamic> json) {
    return PaymentCard(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Card',
      isCredit: (json['isCredit'] as bool?) ?? true,
      billingStartDay: (json['billingStartDay'] as num?)?.toInt() ?? 1,
      dueDay: (json['dueDay'] as num?)?.toInt() ?? 15,
      accountId: (json['accountId'] as String?) ?? '',
    );
  }
}
