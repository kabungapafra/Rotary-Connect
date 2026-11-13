// The printed club QR is now a link to the guest web form, so a phone
// camera without the app opens a form. The in-app scanner must still read
// it as that club — and must keep reading the older JSON codes clubs have
// already printed and stuck on walls, or every one of them stops working.

import 'package:flutter_test/flutter_test.dart';
import 'package:rotary_connect/api_client.dart';
import 'package:rotary_connect/screens/scan_screen.dart';

void main() {
  test('reads the club id from the web-form link', () {
    expect(decodeClubQr('$apiBaseUrl/visit/42'), 42);
  });

  test('still reads QR codes printed in the old format', () {
    expect(decodeClubQr('{"t":"rc_club","id":7}'), 7);
  });

  test('rejects QR codes that are not a club QR', () {
    expect(decodeClubQr('https://example.com/visit/42'), isNull);
    expect(decodeClubQr('$apiBaseUrl/rsvp/42'), isNull);
    expect(decodeClubQr('hello'), isNull);
  });
}
