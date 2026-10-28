#!/usr/bin/env python3
"""Read-only J14 evidence joins. Native Mini remains the authority.

A transport success, an error-free log, or an unrelated old answer does not
establish this row: the selected response must join its definite native hold
settlement and the paid room reply for the selected question.
"""
import argparse
import json
from pathlib import Path
import re


def require(condition, message):
    if not condition:
        raise ValueError(message)


def answered(log, journal, *, route, expected, question):
    calls = [item for item in log if item.get('id') == 'or-call']
    require(bool(calls), 'no Oracle call in this provider transcript')
    require(calls[-1].get('question') == question, 'last Oracle call belongs to another question')
    http = calls[-1].get('result', {}).get('ok', {})
    require(http.get('protocol') == 'mini-spk-agent-api-v3' and http.get('type') == 'http-v3'
            and http.get('status') == 200, 'last Oracle call is not a native HTTP 200 reply')
    body = json.loads(http.get('bodyText', '{}'))
    require(body.get('outcome') == 'completed' and body.get('operation_id') == 'core.query'
            and body.get('reply', {}).get('status') == 'answered'
            and expected in body['reply'].get('response', ''), 'Oracle did not answer the selected query')
    require(all(journal.get(name) is None for name in ['dispatchAttempt', 'dispatchHold', 'dispatchPending']),
            'dispatch has unsettled custody')
    require(isinstance(http.get('operationId'), str) and http.get('committedReceipt') is not None
            and re.fullmatch('[0-9a-f]{64}', http.get('responseSha256', '')) is not None,
            'native reply lacks delivery receipt or response pin')
    matches = [entry for entry in journal.get('applicationApiHistory', [])
               if str(entry.get('operationId')) == http['operationId'] and entry.get('routeName') == route]
    require(len(matches) == 1, 'reply does not identify exactly one native route attempt')
    entry = matches[0]
    require(entry.get('phase') == 'definite' and entry.get('reported') is True,
            'native route attempt is not definite and reported')
    for field, receipt in [('bindingSha256', 'bindingSha256'), ('operationFingerprint', 'operationFingerprint'),
                           ('lifetimeCommittedReceipt', 'committedReceipt'), ('lifetimeSettledResponseSha256', 'responseSha256')]:
        require(http.get(receipt) is not None and entry.get(field) == http[receipt], 'native settlement differs: ' + field)
    settlement = entry.get('lifetimeSettlement', {})
    require(settlement.get('forwardOperationId') == entry['operationId']
            and settlement.get('settlement', {}).get('operation') == 'dispatch settle', 'native lifetime dispatch was not settled')
    return {'protocol': 'mini-j14-oracle-answer-evidence-v1', 'operationId': http['operationId'],
            'response': body['reply']['response'], 'route': route, 'nativeAttempt': entry}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('provider_log', type=Path)
    parser.add_argument('journal', type=Path)
    parser.add_argument('--route', required=True)
    parser.add_argument('--expected', default='Whitman')
    parser.add_argument('--question', required=True)
    args = parser.parse_args()
    records = [json.loads(line) for line in args.provider_log.read_text().splitlines() if line.strip()]
    print(json.dumps(answered(records, json.loads(args.journal.read_text()), route=args.route, expected=args.expected, question=args.question)))


if __name__ == '__main__':
    main()
