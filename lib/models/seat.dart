class Seat {
  Seat(this.number, this.passenger, this.bookedBy);

  final int number;
  String passenger;
  String bookedBy;

  bool isFree() {
    return passenger == '';
  }
}
