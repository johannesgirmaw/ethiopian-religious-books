# Generated manually — custom UserManager for email-as-username users.

from django.db import migrations

import apps.accounts.models


class Migration(migrations.Migration):

    dependencies = [
        ("accounts", "0002_alter_user_groups_alter_user_is_active"),
    ]

    operations = [
        migrations.AlterModelManagers(
            name="user",
            managers=[
                ("objects", apps.accounts.models.UserManager()),
            ],
        ),
    ]
