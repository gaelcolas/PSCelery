#!/usr/bin/python3

from celery import Celery

celery = Celery()
celery.config_from_object('celeryconfig')

task = celery.send_task('celery_worker.tasks.mul', (7, 7))
#task = celery.send_task('celery_worker.tasks.psrp', ('10.111.111.116','Administrator','P@ssw0rd'))
result = task.wait()
print(result)
