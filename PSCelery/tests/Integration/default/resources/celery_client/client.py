#!/usr/bin/python3

from celery import Celery

celery = Celery()
celery.config_from_object('celeryconfig')

task = celery.send_task('celery_worker.tasks.add', (8, 4))
result = task.wait()
print(result)

task = celery.send_task('celery_worker.tasks.mul', (8, 4))
result = task.wait()
print(result)
