import '../../nails/data/models/component_model.dart';
import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/data/models/nail_shape_model.dart';

class TryOnData {
  final List<NailShapeModel> nailShapes;
  final List<ComponentModel> components;
  final List<CustomerComponentModel> customerComponents;

  const TryOnData({
    required this.nailShapes,
    required this.components,
    required this.customerComponents,
  });

  // Combined components (both public and customer)
  List<CombinedComponent> get combinedComponents {
    final List<CombinedComponent> result = [];

    // Add public components
    result.addAll(components.map((c) => CombinedComponent.public(c)));

    // Add customer components
    result.addAll(customerComponents.map((c) => CombinedComponent.customer(c)));

    return result;
  }
}

class CombinedComponent {
  final int id;
  final String name;
  final String imageUrl;
  final ComponentType type;
  final double? price;
  final bool isCustomerComponent;
  final int? customerComponentId;
  final int? componentId;

  CombinedComponent.public(ComponentModel component)
      : id = component.componentId,
        name = component.name,
        imageUrl = component.imageUrl,
        type = _convertComponentType(component.componentType), // Convert here
        price = component.price.toDouble(),
        isCustomerComponent = false,
        customerComponentId = null,
        componentId = component.componentId;

  CombinedComponent.customer(CustomerComponentModel component)
      : id = component.customerComponentId,
        name = component.name,
        imageUrl = component.imageUrl,
        type = _convertComponentType(component.componentType), // Convert here
        price = component.price,
        isCustomerComponent = true,
        customerComponentId = component.customerComponentId,
        componentId = null;

  // Helper method to convert from whatever type your API uses to ComponentType enum
  static ComponentType _convertComponentType(dynamic apiType) {
    // If API returns int (0, 1, 2, 3)
    if (apiType is int) {
      return ComponentType.fromValue(apiType);
    }
    // If API returns String ('gem', 'sticker', etc.)
    if (apiType is String) {
      switch (apiType.toLowerCase()) {
        case 'gem':
          return ComponentType.gem;
        case 'sticker':
          return ComponentType.sticker;
        case 'charm':
          return ComponentType.charm;
        case 'art':
          return ComponentType.art;
        default:
          return ComponentType.gem;
      }
    }
    // Default fallback
    return ComponentType.gem;
  }
}

enum ComponentType {
  gem(0),
  sticker(1),
  charm(2),
  art(3);

  final int value;
  const ComponentType(this.value);

  static ComponentType fromValue(int value) {
    return ComponentType.values.firstWhere(
          (e) => e.value == value,
      orElse: () => ComponentType.gem,
    );
  }

  // Optional: convert enum to string if needed
  String get stringValue {
    switch (this) {
      case ComponentType.gem:
        return 'gem';
      case ComponentType.sticker:
        return 'sticker';
      case ComponentType.charm:
        return 'charm';
      case ComponentType.art:
        return 'art';
    }
  }
}