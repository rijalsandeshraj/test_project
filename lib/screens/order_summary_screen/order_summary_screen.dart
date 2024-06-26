// ignore_for_file: use_build_context_synchronously

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shoesly/constants/colors.dart';
import 'package:shoesly/constants/constants.dart';
import 'package:shoesly/constants/text_styles.dart';
import 'package:shoesly/cubits/product/product_cubit.dart';
import 'package:shoesly/models/order.dart';
import 'package:shoesly/screens/discover_screen/discover_screen.dart';
import 'package:shoesly/screens/map_screen.dart';
import 'package:shoesly/screens/payment_method_screen.dart';
import 'package:shoesly/services/location_service.dart';
import 'package:shoesly/utils/navigator.dart';
import 'package:shoesly/utils/show_custom_snack_bar.dart';
import 'package:shoesly/widgets/bottom_app_bar_widget.dart';
import 'package:shoesly/widgets/button_widget.dart';
import 'package:shoesly/widgets/check_mark_widget.dart';
import 'package:shoesly/widgets/custom_app_bar.dart';
import 'package:shoesly/widgets/loading_widget.dart';

import '../../models/product.dart';
import '../../services/product_services.dart';
import 'widgets/payment_detail_widget.dart';

class OrderSummaryScreen extends StatefulWidget {
  const OrderSummaryScreen({super.key, required this.totalPrice});

  final double totalPrice;

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  bool loading = false;
  bool gettingLocation = false;
  bool productsAddedForOrder = false;
  bool orderPlaced = false;
  int productTypesQty = 0;
  LocationPermission locationPermission = LocationPermission.denied;
  var order = Order(
    products: [],
    paymentMethod: paymentMethods.first,
    address: 'Default Location',
    geoPoint: const GeoPoint(0, 0),
    orderedDateTime: DateTime.timestamp().toLocal(),
    shippingCharge: 20,
    grandTotal: 0,
  );

  String totalPricePerQuantity(Product product) {
    num price = product.quantity * (product.price);
    return price.toStringAsFixed(2);
  }

  Future<void> getAddress(
      double latitude, double longitude, BuildContext context) async {
    order.geoPoint = GeoPoint(latitude, longitude);
    order.address = await LocationService().getAddress(latitude, longitude);
    String successMessage = 'Location fetched successfully';
    if (order.address == 'Default Location') {
      successMessage +=
          '! Check internet connection for fetching your actual address.';
    }
    showCustomSnackBar(context, successMessage);
  }

  Future<bool?> _showLocationAccessDialog(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
            'Location permission is required for accessing your current location'),
        content: const Text(
            'Pressing \'CONFIRM\' will access your current location!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('CONFIRM'),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showOrderConfirmationDialog(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure about placing this order?'),
        content: const Text('Pressing \'YES\' will place your order!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('NO'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('YES'),
          ),
        ],
      ),
    );
  }

  // Bottom sheet shown while order is saved to the database
  Future<dynamic> _showOrderPlacedBottomSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.0),
          topRight: Radius.circular(20.0),
        ),
      ),
      backgroundColor: AppColor.white,
      isScrollControlled: false,
      isDismissible: false,
      builder: (context) {
        return PopScope(
          canPop: false,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CheckMarkWidget(),
                  const SizedBox(height: 20),
                  const Text(
                    'Order Placed Successfully!',
                    style: homeCategoryTextStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '$productTypesQty Item(s) Total',
                    style: descriptionTextStyle.copyWith(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  ButtonWidget(
                      title: 'BACK EXPLORE',
                      onPressed: () {
                        Navigator.pop(context);
                        navigateAndRemoveUntil(
                            context: context, screen: const DiscoverScreen());
                      }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double grandTotal = widget.totalPrice + 20;
    order.grandTotal = grandTotal;
    return BlocBuilder<ProductCubit, ProductState>(
      builder: (context, state) {
        productTypesQty = state.cartProducts.length;
        return Scaffold(
          appBar: const CustomAppBar(title: 'Order Summary'),
          bottomNavigationBar: state.cartProducts.isNotEmpty
              ? BottomAppBarWidget(
                  leadingElementTitle: 'Grand Total',
                  leadingElementValue: '\$${grandTotal.toStringAsFixed(2)}',
                  actionTitle: 'PAYMENT',
                  onPressed: () {
                    if (loading || gettingLocation) return;
                    _showOrderConfirmationDialog(context).then((value) async {
                      if (value == true) {
                        setState(() {
                          loading = true;
                        });
                        order.orderedDateTime = DateTime.timestamp().toLocal();
                        try {
                          await ProductServices().addOrderToFirestore(order);
                          setState(() {
                            loading = false;
                          });
                          context.read<ProductCubit>().clearCartItems();
                          _showOrderPlacedBottomSheet(context);
                        } catch (e) {
                          setState(() {
                            loading = false;
                          });
                          showCustomSnackBar(
                              context, 'Error while placing the order');
                        }
                      }
                    });
                  },
                )
              : null,
          body: state.cartProducts.isNotEmpty
              ? SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(30),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Information',
                              style: headerTextStyle.copyWith(fontSize: 18)),
                          const SizedBox(height: 20),
                          GestureDetector(
                            onTap: () {
                              if (loading || gettingLocation) return;
                              navigateTo(context, const PaymentMethodScreen())
                                  .then((value) {
                                if (paymentMethods.contains(value.toString())) {
                                  setState(() {
                                    order.paymentMethod = value;
                                  });
                                }
                              });
                            },
                            child: Container(
                              color: AppColor.transparent,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text('Payment Method',
                                          style: reviewerTextStyle),
                                      const SizedBox(height: 10),
                                      Text(order.paymentMethod,
                                          style: descriptionTextStyle.copyWith(
                                              fontSize: 14)),
                                    ],
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: AppColor.secondaryTextColor,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 15),
                          const Divider(color: Colors.black, thickness: 0.1),
                          const SizedBox(height: 15),
                          GestureDetector(
                            onTap: () async {
                              if (loading || gettingLocation) return;
                              bool? allowLocationService =
                                  await _showLocationAccessDialog(context);
                              if (allowLocationService == true) {
                                setState(() {
                                  gettingLocation = true;
                                });
                                locationPermission =
                                    await LocationService().requestService();
                                if (locationPermission ==
                                    LocationPermission.denied) {
                                  showCustomSnackBar(
                                      context, 'Location permission is denied',
                                      taskSuccess: false);
                                } else if (locationPermission ==
                                    LocationPermission.deniedForever) {
                                  showCustomSnackBar(context,
                                      'Location permission is permanently denied. Enable location permission in Settings.',
                                      taskSuccess: false);
                                } else {
                                  var position = await LocationService()
                                      .getCurrentPosition();
                                  await getAddress(position.latitude,
                                      position.longitude, context);
                                }
                                setState(() {
                                  gettingLocation = false;
                                });
                              }
                            },
                            child: Container(
                              color: AppColor.transparent,
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Location',
                                            style: reviewerTextStyle),
                                        const SizedBox(height: 10),
                                        Text(order.address,
                                            style: descriptionTextStyle
                                                .copyWith(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  Flexible(
                                    flex: 1,
                                    child: order.geoPoint.latitude == 0
                                        ? const Icon(
                                            Icons.arrow_forward_ios,
                                            color: AppColor.secondaryTextColor,
                                            size: 16,
                                          )
                                        : ActionChip(
                                            label: const FittedBox(
                                              child: Text('See in Map',
                                                  style: reviewTextStyle),
                                            ),
                                            padding: EdgeInsets.zero,
                                            color: MaterialStatePropertyAll(
                                                AppColor.primary
                                                    .withOpacity(0.6)),
                                            shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(20)),
                                            onPressed: () {
                                              navigateTo(
                                                      context,
                                                      MapScreen(
                                                          latLng: LatLng(
                                                              order.geoPoint
                                                                  .latitude,
                                                              order.geoPoint
                                                                  .longitude)))
                                                  .then((value) async {
                                                if (value is LatLng &&
                                                    value.latitude !=
                                                        order.geoPoint
                                                            .latitude &&
                                                    value.longitude !=
                                                        order.geoPoint
                                                            .longitude) {
                                                  setState(() {
                                                    gettingLocation = true;
                                                  });
                                                  await getAddress(
                                                      value.latitude,
                                                      value.longitude,
                                                      context);
                                                  setState(() {
                                                    gettingLocation = false;
                                                  });
                                                }
                                              });
                                            },
                                          ),
                                  )
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text('Order Detail',
                              style:
                                  homeCategoryTextStyle.copyWith(fontSize: 18)),
                          const SizedBox(height: 20),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            cacheExtent: 10000,
                            itemCount: state.cartProducts.length,
                            itemBuilder: (context, index) {
                              final cartProduct = state.cartProducts[index];
                              String totalPricePerProduct =
                                  totalPricePerQuantity(cartProduct);
                              if (!productsAddedForOrder) {
                                order.products.add(cartProduct.toJsonForOrder(
                                    double.tryParse(totalPricePerProduct) ??
                                        0));
                              }
                              if (index == state.cartProducts.length - 1) {
                                productsAddedForOrder = true;
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cartProduct.name,
                                      style: primaryTextStyle),
                                  const SizedBox(height: 5),
                                  Row(
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: '${cartProduct.brand} . ',
                                              style: descriptionTextStyle
                                                  .copyWith(fontSize: 14),
                                            ),
                                            TextSpan(
                                              text:
                                                  '${cartProduct.selectedColor?.title ?? 'Color N/A'} . ',
                                              style: descriptionTextStyle
                                                  .copyWith(fontSize: 14),
                                            ),
                                            TextSpan(
                                              text:
                                                  '${cartProduct.selectedSize} . ',
                                              style: descriptionTextStyle
                                                  .copyWith(fontSize: 14),
                                            ),
                                            TextSpan(
                                              text:
                                                  'Qty ${cartProduct.quantity} * ',
                                              style: descriptionTextStyle
                                                  .copyWith(fontSize: 14),
                                            ),
                                            TextSpan(
                                                text: '\$${cartProduct.price}',
                                                style: descriptionTextStyle
                                                    .copyWith(fontSize: 14))
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        '\$$totalPricePerProduct',
                                        style: reviewerTextStyle,
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                            separatorBuilder: (__, _) => const SizedBox(
                              height: 20,
                            ),
                          ),
                          const SizedBox(height: 30),
                          Text(
                            'Payment Detail',
                            style: homeCategoryTextStyle.copyWith(fontSize: 18),
                          ),
                          const SizedBox(height: 20),
                          PaymentDetailWidget(
                              title: 'Subtotal',
                              amount:
                                  '\$${widget.totalPrice.toStringAsFixed(2)}'),
                          const SizedBox(height: 20),
                          const PaymentDetailWidget(
                              title: 'Shipping', amount: '\$20.00'),
                          const SizedBox(height: 10),
                          const Divider(color: Colors.black, thickness: 0.1),
                          const SizedBox(height: 10),
                          PaymentDetailWidget(
                              title: 'Total Order',
                              amount: '\$$grandTotal',
                              forTotalOrder: true),
                          const SizedBox(height: 60),
                        ],
                      ),
                      if (loading) const LoadingWidget(),
                      if (gettingLocation)
                        const LoadingWidget(title: 'Getting location...')
                    ],
                  ),
                )
              : Center(
                  child: Text(
                    'No Orders Found',
                    style: primaryTextStyle.copyWith(color: AppColor.red),
                  ),
                ),
        );
      },
    );
  }
}
