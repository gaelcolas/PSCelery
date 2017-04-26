#!/usr/bin/python3

from celery import Celery

app = Celery('tasks', include=['celery_worker.tasks'])
app.config_from_object('celery_worker.celeryconfig')

if __name__ == '__main__':
    app.start()
