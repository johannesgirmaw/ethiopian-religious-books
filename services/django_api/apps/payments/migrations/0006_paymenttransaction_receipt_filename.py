from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("payments", "0005_uniq_user_book_active_purchase"),
    ]

    operations = [
        migrations.AddField(
            model_name="paymenttransaction",
            name="receipt_filename",
            field=models.CharField(blank=True, max_length=255),
        ),
    ]
