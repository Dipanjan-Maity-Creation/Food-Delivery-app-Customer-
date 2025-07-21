class Dish {
  final String name;
  final String description;
  final double price;
  final double rating;
  final String category; //



  int quantity;
  final String? imageUrl; // Add this field

  Dish({
    required this.name,
    required this.description,
    required this.price,
    required this.rating,
    this.quantity = 0,
    required this.category,
    this.imageUrl, // Nullable to handle cases where no image is provided
  });
}