#!/usr/bin/env python3
"""J14 fork for hosted apps through Hermes: one Store, one controller, typed app tools.

Reuses the J14_ORACLE driver's native phases; J14_APPS_UNTIL names the last phase to run
(world, prepare_platform, prepare_application). The Oracle data publication is never run.
"""
import fcntl, importlib.util, os, sys
from pathlib import Path
HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('j14_oracle',HERE/'j14-oracle.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
ORDER=['world','prepare_platform','prepare_application']
def main():
    until=os.environ.get('J14_APPS_UNTIL','prepare_application')
    if until not in ORDER:raise SystemExit('J14_APPS_UNTIL must be one of '+','.join(ORDER))
    j=m.Journey();phase='init'
    try:
        for phase in ORDER[:ORDER.index(until)+1]:
            if phase=='world':
                # hbox convention: world-up serialized by a lock held only around world-up.
                with open('/tank/lanes/world-up.lock','a') as lock:
                    fcntl.flock(lock,fcntl.LOCK_EX);getattr(j,phase)()
            else:getattr(j,phase)()
            m.write(j.root/('context-after-'+phase+'.json'),j.c)
            print('phase done',phase,flush=True)
    except Exception as error:
        m.write(j.root/'failure.json',{'phase':phase,'error':str(error),'passed':False,'lastCommand':j.counter})
        raise
    finally:j.cleanup()
if __name__=='__main__':main()
