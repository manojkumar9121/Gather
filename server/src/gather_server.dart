import 'package:modules/serverpod/serverpod.dart';
import 'package:gather_server/src/protocol/protocol.dart';
import 'package:gather_server/src/endpoints/gather_endpoint.dart';

void main(List<String> args) async {
  final pod = Serverpod(
    args,
    Protocol(),
    Endpoints(),
    authenticationHandler: EndpointAuthenticationHandler(),
  );
  await pod.start();
}
