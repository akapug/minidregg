import unittest
from binding import Refusal, dav_decode, rss_decode


class XMLSafeEncoding(unittest.TestCase):
    def test_alternate_encoding_cannot_hide_a_dtd(self):
        xml = '<!DOCTYPE multistatus [<!ENTITY x "secret">]><multistatus xmlns="DAV:"><response><href>&x;</href><propstat><status>HTTP/1.1 200 OK</status><prop><resourcetype/></prop></propstat></response></multistatus>'
        for encoding in ('utf-16', 'utf-16-le', 'utf-32'):
            with self.subTest(encoding=encoding):
                with self.assertRaises(Refusal):
                    dav_decode(xml.encode(encoding))

    def test_utf8_dav_and_rss_still_decode(self):
        self.assertEqual(dav_decode(b'<multistatus xmlns="DAV:"/>'), [])
        self.assertEqual(rss_decode(b'<rss version="2.0"><channel/></rss>', 1), [])
