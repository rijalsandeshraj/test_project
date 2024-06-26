part of 'product_cubit.dart';

enum ProductStatus {
  loading,
  success,
  error,
}

class ProductState
//  extends Equatable
{
  const ProductState({
    this.status = ProductStatus.loading,
    this.products = const [],
    this.filteredProducts = const [],
    this.cartProducts = const [],
    this.message,
  });

  final ProductStatus status;
  final List<Product> products;
  final List<Product> filteredProducts;
  final List<Product> cartProducts;
  // The info or error message to be displayed as a snackbar
  final String? message;

  ProductState copyWith({
    ProductStatus? status,
    List<Product>? products,
    List<Product>? filteredProducts,
    List<Product>? cartProducts,
    String? message,
  }) {
    return ProductState(
      status: status ?? this.status,
      products: products ?? this.products,
      filteredProducts: filteredProducts ?? this.filteredProducts,
      cartProducts: cartProducts ?? this.cartProducts,
      message: message ?? this.message,
    );
  }

  // @override
  // List<Object?> get props => [
  //       status,
  //       products,
  //       filteredProducts,
  //       cartProducts,
  //       message,
  //     ];
}
