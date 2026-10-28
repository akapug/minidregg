"""RSS is an explicit data feed, never an HTML scraping fallback."""
from unittest import TestCase, main
from binding import Refusal, rss_decode, decode_http

class RSSFeed(TestCase):
    def test_video_feed_metadata_and_binary_enclosure(self):
        raw = b'''<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom"><channel>
        <title>Library</title><atom:link href="ignored"/><item><guid>https://grain.test/v/one</guid>
        <title>A &amp; B</title><link>https://grain.test/v/one</link><description>video data</description>
        <pubDate>Wed, 28 Oct 2026 12:00:00 GMT</pubDate>
        <enclosure url="https://grain.test/v/one.mp4" length="2600" type="video/mp4"/>
        </item></channel></rss>'''
        self.assertEqual(rss_decode(raw, 10), [{'id': 'https://grain.test/v/one', 'title': 'A & B',
            'link': 'https://grain.test/v/one', 'description': 'video data',
            'published': 'Wed, 28 Oct 2026 12:00:00 GMT',
            'enclosure': {'url': 'https://grain.test/v/one.mp4', 'bytes': 2600, 'type': 'video/mp4'}}])

    def test_no_entity_html_or_namespace_confusion(self):
        samples = ['<!DOCTYPE rss [<!ENTITY x "hidden">]><rss version="2.0"><channel/></rss>'.encode('utf-16'),
                   b'<!DOCTYPE rss [<!ENTITY x "hidden">]><rss version="2.0"><channel/></rss>',
                   b'<html><body>not a feed</body></html>',
                   b'<rss xmlns="urn:forged" version="2.0"><channel/></rss>',
                   b'<rss version="2.0"><channel/><channel/></rss>',
                   b'<rss version="2.0"><channel><item><guid>x</guid><enclosure url="x" length="-1" type="video/mp4"/></item></channel></rss>']
        for raw in samples:
            with self.assertRaises(Refusal):
                rss_decode(raw, 10)

    def test_http_decoder_dispatches_declared_rss(self):
        declaration = {'limits': {'replyBytes': 4096, 'snapshotDocuments': 10}}
        op = {'write': False, 'binding': {'decode': 'rss', 'status': [200]}}
        self.assertEqual(decode_http(declaration, op,
            (200, {'content-type': 'text/xml'}, b'<rss version="2.0"><channel/></rss>')), [])

    def test_item_limit_checked_before_emitting_feed(self):
        raw = b'<rss version="2.0"><channel><item><guid>one</guid></item><item><guid>two</guid></item></channel></rss>'
        with self.assertRaises(Refusal) as raised:
            rss_decode(raw, 1)
        self.assertEqual(raised.exception.name, 'rss-items-over-bound')

if __name__ == '__main__':
    main()
