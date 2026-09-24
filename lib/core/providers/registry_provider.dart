import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'default_registry.dart';
import 'provider_registry.dart';

final providerRegistryProvider = Provider<ProviderRegistry>(
  (_) => defaultRegistry,
);
