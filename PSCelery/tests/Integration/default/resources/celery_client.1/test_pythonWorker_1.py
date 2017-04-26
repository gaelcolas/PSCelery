#!/usr/bin/python3

from celery import Celery

celery = Celery()
celery.config_from_object('celeryconfig')

task = celery.send_task('cdcworker.celery_app.test', (7, 7))
result = task.wait()
print(result)
