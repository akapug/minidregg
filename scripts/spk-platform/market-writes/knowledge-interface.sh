# Semantic app rows share the same declaration path as generated native tools.
# Unsupported writes fail by their source-backed name; exports are never write PASS.
write_MediaWiki() { typed_app_row mediawiki; }
write_Etherpad() { typed_app_row etherpad; }
write_EtherCalc() { typed_app_row ethercalc; }
write_Radicale() { typed_app_row radicale; }
write_Hugo() { typed_app_row hugo; }
write_WordPress() { typed_app_row wordpress; }
write_Linksholder() { typed_app_row linksholder; }
write_TinyTinyRSS() { typed_app_row ttrss; }
write_TTRSS() { typed_app_row ttrss; }
write_DokuWiki() { echo '0 dokuwiki-remote-interface-disabled-by-package-default; raw page export is read-only'; }
write_SandCal() { echo '0 sandcal-semantic-csrf-endpoint-absent; iCalendar export is read-only'; }
write_Permanote() { echo '0 permanote-semantic-note-read-endpoint-absent; HTML note readback is not a typed interface'; }
write_HedgeDoc() { echo '0 hedgedoc-iconv-encodings-absent; socket OT native write remains unqualified'; }
write_HedgeDocRT() { write_HedgeDoc; }
