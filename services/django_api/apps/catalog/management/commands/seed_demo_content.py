"""
Seed ~30 realistic, fully-published books (Amharic + English) plus data for
*every* backend feature: tags, multiple users, the full study suite
(folders, bookmarks, highlights, notes, folder entries, reading plans + items,
reminder preferences, reminders, reading progress, reader events) and legal
documents + acceptances.

Idempotent: safe to run repeatedly (keys on natural fields / get_or_create).

Run:
    docker compose -f infra/docker-compose.yml --env-file infra/.env \
        exec api python manage.py seed_demo_content
    # or: make seed-demo  (if wired)
"""

from __future__ import annotations

from datetime import timedelta

from django.contrib.auth import get_user_model
from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.catalog.models import Book, BookContentIndex, BookPage, BookTag, Tag
from apps.catalog.publishing import publish_book
from apps.catalog.storage_s3 import ensure_bucket, is_object_storage_configured
from apps.legal.models import LegalAcceptance, LegalDocument
from apps.study.models import (
    DailyReadingPlan,
    DailyReadingPlanItem,
    ReaderEvent,
    ReminderPreference,
    StudyFolder,
    StudyFolderEntry,
    StudyReminder,
    UserBookmark,
    UserHighlight,
    UserNote,
    UserReadingProgress,
)

User = get_user_model()


def _p(title: str, body: str) -> dict:
    return {"title": title, "body": body}


def _ch(title: str, pages: list[dict]) -> dict:
    return {"title": title, "pages": pages}


# --- Tag catalogue (slug -> human label) -----------------------------------
TAGS = {
    "liturgy": "ሥርዓተ ቅዳሴ / Liturgy",
    "prayer": "ጸሎት / Prayer",
    "marian": "ማርያማዊ / Marian",
    "saints": "ቅዱሳን / Saints",
    "psalms": "መዝሙረ ዳዊት / Psalms",
    "gospel": "ወንጌል / Gospel",
    "history": "ታሪክ / History",
    "teaching": "ትምህርት / Teaching",
    "devotion": "ምሥጢረ ጸሎት / Devotion",
    "canon": "ቀኖና / Canon",
    "amharic": "አማርኛ / Amharic",
    "english": "English",
}


# --- Book seeds. language: "am" or "en". -----------------------------------
BOOKS: list[dict] = [
    {
        "title": "መዝሙረ ዳዊት",
        "subtitle": "የንጉሥ ዳዊት መዝሙራት",
        "summary": "ከመጽሐፍ ቅዱስ የተወሰዱ የንጉሥ ዳዊት መዝሙራት — ለጸሎትና ለምስጋና።",
        "author": "ቅዱስ ዳዊት ነቢይ",
        "language": "am",
        "tags": ["psalms", "prayer", "amharic"],
        "chapters": [
            _ch("መዝሙር ፩", [
                _p("ምስጉን ሰው", "በክፉዎች ምክር ያልሄደ፣ በኃጢአተኞችም መንገድ ያልቆመ፣ በዋዘኞችም ወንበር ያልተቀመጠ ሰው ምስጉን ነው። ነገር ግን በእግዚአብሔር ሕግ ደስ ይለዋል፣ ሕጉንም ቀንና ሌሊት ያስባል።"),
                _p("እንደ ዛፍ", "እርሱም በውኃ ፈሳሾች ዘንድ እንደ ተተከለች ዛፍ ይሆናል፤ ፍሬዋን በየጊዜዋ የምትሰጥ፣ ቅጠልዋም የማይረግፍ። ክፉዎች ግን እንዲህ አይደሉም፤ ነገር ግን ነፋስ እንደሚበትነው ገለባ ናቸው።"),
            ]),
            _ch("መዝሙር ፳፫", [
                _p("እግዚአብሔር እረኛዬ ነው", "እግዚአብሔር እረኛዬ ነው፣ የሚያሳጣኝም የለም። በለመለመ መስክ ያሳድረኛል፤ በዕረፍት ውኃ ዘንድ ይመራኛል። ነፍሴን ይመልሳል፤ ስለ ስሙም በጽድቅ መንገድ ይመራኛል።"),
            ]),
        ],
    },
    {
        "title": "ውዳሴ ማርያም",
        "subtitle": "የእመቤታችን ቅድስት ድንግል ማርያም ምስጋና",
        "summary": "በየዕለቱ የሚነበብ የእመቤታችን ምስጋና — የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ ክርስቲያን ትውፊት።",
        "author": "ቅዱስ ኤፍሬም ሶርያዊ",
        "language": "am",
        "tags": ["marian", "liturgy", "devotion", "amharic"],
        "chapters": [
            _ch("ዘሰኑይ", [
                _p("የሰኞ ውዳሴ", "ሰላም ለኪ እንበል በመላእክት ቃል፣ ድንግል ማርያም የብርሃን እናቱ። ካህናት በምስጋና ያከብሩሻል፤ ምእመናንም በፍቅር ይዘምሩልሻል። አንቺ የሰማይና የምድር ንግሥት ነሽ።"),
                _p("ምልጃ", "እመቤታችን ሆይ፣ ስለ እኛ ኃጢአተኞች ለልጅሽ ለመድኃኒታችን ለመነኝ። ከኃጢአት ጨለማ ወደ ብርሃን ምሪን፤ በምሕረትሽም ጥላ ሰውሪን።"),
            ]),
            _ch("ዘሠሉስ", [
                _p("የማክሰኞ ውዳሴ", "ቡርክት አንቺ ከሴቶች ሁሉ፣ ቡሩክም የማሕፀንሽ ፍሬ። የነቢያት ትንቢት በአንቺ ተፈጸመ፤ ዓለምም በአንቺ ድኅነትን አገኘ።"),
            ]),
        ],
    },
    {
        "title": "ጸሎተ ሃይማኖት",
        "subtitle": "የሃይማኖት መግለጫ",
        "summary": "በ፫፻፲፰ቱ ሊቃውንት የተወሰነ የቤተ ክርስቲያን የሃይማኖት መግለጫ።",
        "author": "ሊቃውንተ ኒቅያ",
        "language": "am",
        "tags": ["canon", "teaching", "amharic"],
        "chapters": [
            _ch("የሃይማኖት ቃል", [
                _p("በአንዱ አምላክ", "በአንዱ አምላክ በእግዚአብሔር አብ፣ ሰማይንና ምድርን የሚታየውንና የማይታየውን ሁሉ በፈጠረ እናምናለን። በአንዱ ጌታ በኢየሱስ ክርስቶስ፣ ከዘመናት ሁሉ በፊት ከአብ በተወለደ።"),
                _p("ስለ ድኅነት", "ስለ እኛ ስለ ሰዎች ስለ መዳናችንም ከሰማይ ወረደ፤ ከመንፈስ ቅዱስና ከድንግል ማርያም ሰው ሆነ። በጴንጤናዊው ጲላጦስ ዘመንም ስለ እኛ ተሰቀለ።"),
            ]),
        ],
    },
    {
        "title": "አቡነ ዘበሰማያት",
        "subtitle": "ጌታ ያስተማረን ጸሎት",
        "summary": "ጌታችን ኢየሱስ ክርስቶስ ያስተማረን የጌታ ጸሎትና ማብራሪያው።",
        "author": "ትውፊተ ቤተ ክርስቲያን",
        "language": "am",
        "tags": ["prayer", "teaching", "amharic"],
        "chapters": [
            _ch("የጌታ ጸሎት", [
                _p("አባታችን ሆይ", "አባታችን ሆይ በሰማያት የምትኖር፣ ስምህ ይቀደስ፤ መንግሥትህ ትምጣ፤ ፈቃድህ በሰማይ እንደ ሆነች እንዲሁ በምድር ትሁን።"),
                _p("የዕለት እንጀራ", "የዕለት እንጀራችንን ስጠን ዛሬ፤ በደላችንንም ይቅር በለን፤ እኛም ደግሞ የበደሉንን ይቅር እንደምንል። ከክፉም አድነን እንጂ ወደ ፈተና አታግባን።"),
            ]),
        ],
    },
    {
        "title": "ስንክሳር",
        "subtitle": "የቅዱሳን ዕለታዊ መታሰቢያ",
        "summary": "በየዕለቱ የሚነበብ የቅዱሳንና የሰማዕታት መታሰቢያ መጽሐፍ።",
        "author": "የኢትዮጵያ ኦርቶዶክስ ትውፊት",
        "language": "am",
        "tags": ["saints", "liturgy", "history", "amharic"],
        "chapters": [
            _ch("መስከረም", [
                _p("ርእሰ ዐውደ ዓመት", "መስከረም አንድ ቀን የዓመቱ መጀመሪያ ነው። በዚህ ዕለት ቅዱስ ዮሐንስ መጥምቅ ይታሰባል፤ ቤተ ክርስቲያንም አዲሱን ዓመት በምስጋና ትቀበላለች።"),
                _p("ቅዱስ ሩፋኤል", "የመላእክት አለቃ ቅዱስ ሩፋኤል የሕሙማን ጠባቂ ነው። ምእመናን በበሽታ ጊዜ ምልጃውን ይለምናሉ፤ ስለ ፈውስም ያመሰግናሉ።"),
            ]),
            _ch("ጥቅምት", [
                _p("አቡነ ተክለ ሃይማኖት", "ጻድቁ አቡነ ተክለ ሃይማኖት በጾምና በጸሎት ሕይወታቸውን ያሳለፉ ኢትዮጵያዊ ቅዱስ ናቸው። ለሰባት ዓመት በአንድ እግራቸው ቆመው ጸልየዋል ይባላል።"),
            ]),
        ],
    },
    {
        "title": "የዮሐንስ ወንጌል",
        "subtitle": "የኢትዮጵያ የጥናት እትም",
        "summary": "የዮሐንስ ወንጌል በአማርኛ ከትርጓሜ ማስታወሻ ጋር።",
        "author": "ቅዱስ ዮሐንስ ወንጌላዊ",
        "language": "am",
        "tags": ["gospel", "teaching", "amharic"],
        "chapters": [
            _ch("ምዕራፍ ፩", [
                _p("ቃል ሥጋ ሆነ", "በመጀመሪያ ቃል ነበረ፣ ቃልም በእግዚአብሔር ዘንድ ነበረ፣ ቃልም እግዚአብሔር ነበረ። ሁሉ በእርሱ ሆነ፤ ከሆነውም አንዳች ስንኳ ያለ እርሱ አልሆነም።"),
                _p("ብርሃኑ", "ሕይወት በእርሱ ነበረች፣ ሕይወትም የሰው ብርሃን ነበረች። ብርሃንም በጨለማ ይበራል፣ ጨለማም አላሸነፈውም።"),
            ]),
        ],
    },
    {
        "title": "ድርሳነ ሚካኤል",
        "subtitle": "የቅዱስ ሚካኤል ድርሳን",
        "summary": "ስለ መላእክት አለቃ ቅዱስ ሚካኤል ምልጃና ተአምራት የሚተርክ ድርሳን።",
        "author": "ትውፊተ ድርሳን",
        "language": "am",
        "tags": ["saints", "devotion", "amharic"],
        "chapters": [
            _ch("የሚካኤል ክብር", [
                _p("የመላእክት አለቃ", "ቅዱስ ሚካኤል በሰማይ ካሉ መላእክት አለቃ ነው። በፊተ እግዚአብሔር ቆሞ ስለ ሰው ልጆች ይማልዳል፤ ጠላትንም ድል ይነሣል።"),
                _p("ጥበቃ", "ቅዱስ ሚካኤል በመንገድ ለሚሄዱ ጠባቂ፣ ለተጨነቁም አጽናኝ ነው። ስሙን የሚጠራ ሁሉ በክንፉ ጥላ ይጠበቃል።"),
            ]),
        ],
    },
    {
        "title": "ተአምረ ማርያም",
        "subtitle": "ከኢትዮጵያ ትውፊት የተመረጡ",
        "summary": "በእመቤታችን ቅድስት ድንግል ማርያም ምልጃ የተደረጉ ተአምራት ስብስብ።",
        "author": "ትውፊታዊ ዘገባ",
        "language": "am",
        "tags": ["marian", "devotion", "amharic"],
        "chapters": [
            _ch("የመጀመሪያው ተአምር", [
                _p("የችግረኛው ምልጃ", "አንድ ድሃ ሰው በችግር ተውጦ ወደ እመቤታችን ጸለየ። እመቤታችንም ምልጃውን ሰምታ ከመከራው አዳነችው፤ እርሱም ዕድሜ ልኩን አመሰገናት።"),
            ]),
            _ch("ሁለተኛው ተአምር", [
                _p("የታመመው ልጅ", "የአንዲት እናት ልጅ ታሞ ሊሞት ሲል እመቤታችንን ለመነች። በእምነቷም ምክንያት ልጁ ዳነ፤ ቤተሰቡም ሁሉ አመነ።"),
            ]),
        ],
    },
    {
        "title": "መጽሐፈ ሄኖክ",
        "subtitle": "የግዕዝ እትም በአማርኛ",
        "summary": "በኢትዮጵያ ቀኖና የተጠበቀ የሄኖክ መጽሐፍ ትርጓሜ።",
        "author": "ሄኖክ ጻድቅ",
        "language": "am",
        "tags": ["canon", "history", "amharic"],
        "chapters": [
            _ch("ምዕራፍ ፩", [
                _p("የሄኖክ ቃል", "የሄኖክ ቃል፣ የተባረከውን ትውልድ የባረከበት። ሄኖክ ጻድቅ ሰው ነበረ፤ የእግዚአብሔርም ራእይ ተገለጠለት፤ የሰማይንም ምስጢር አየ።"),
            ]),
        ],
    },
    {
        "title": "ፍትሐ ነገሥት",
        "subtitle": "የነገሥታት ሕግ",
        "summary": "የቤተ ክርስቲያንና የመንግሥት ሕግጋትን የያዘ ጥንታዊ የኢትዮጵያ ሕገ መጽሐፍ።",
        "author": "ትርጓሜ ሊቃውንት",
        "language": "am",
        "tags": ["canon", "history", "teaching", "amharic"],
        "chapters": [
            _ch("ስለ ቤተ ክርስቲያን ሥርዓት", [
                _p("የካህናት ሥርዓት", "ካህናት የእግዚአብሔርን ቤት በንጽሕና ሊያገለግሉ ይገባል። በጾምና በጸሎት ጸንተው ለምእመናን አርአያ ይሁኑ።"),
                _p("ስለ ፍርድ", "ፍርድ በእውነትና በምሕረት ይሁን። ዳኛ አድልዎ ሳያደርግ፣ ለድሃውና ለባለጠጋው እኩል ይፍረድ።"),
            ]),
        ],
    },
    {
        "title": "መልክአ ኢየሱስ",
        "subtitle": "የጌታችን ምስጋና",
        "summary": "የጌታችን የመድኃኒታችን የኢየሱስ ክርስቶስን አካላት እያነሱ የሚያመሰግን ጸሎት።",
        "author": "ትውፊተ ቤተ ክርስቲያን",
        "language": "am",
        "tags": ["prayer", "devotion", "amharic"],
        "chapters": [
            _ch("ሰላምታ", [
                _p("ሰላም ለርእስከ", "ሰላም ለርእስከ ለመድኃኒታችን፣ የክብር ዘውድ ለተቀዳጀ። ሰላም ላንተ ለፊትህ ብርሃን ለሚመስል፣ ጨለማን ሁሉ ለሚያርቅ።"),
            ]),
        ],
    },
    {
        "title": "ቅዳሴ ማርያም",
        "subtitle": "የእመቤታችን ቅዳሴ",
        "summary": "በቅዱስ ኤጲፋንዮስ የተደረሰ የእመቤታችን ቅዳሴ ሥርዓት።",
        "author": "ቅዱስ ኤጲፋንዮስ",
        "language": "am",
        "tags": ["marian", "liturgy", "amharic"],
        "chapters": [
            _ch("መግቢያ", [
                _p("ምስጋና", "የእመቤታችንን ክብር በምን እንመስለዋለን? እርሷ ከኪሩቤል ትበልጣለች፤ ከሱራፌልም ትከብራለች። የፈጣሪን እናት ምስጋናዋ ይገባል።"),
            ]),
        ],
    },
    {
        "title": "አርጋኖን",
        "subtitle": "የእመቤታችን ሰባት ቀን ምስጋና",
        "summary": "በአባ ጊዮርጊስ ዘጋሥጫ የተደረሰ የሰባት ቀን የእመቤታችን ምስጋና።",
        "author": "አባ ጊዮርጊስ ዘጋሥጫ",
        "language": "am",
        "tags": ["marian", "prayer", "devotion", "amharic"],
        "chapters": [
            _ch("ዘሰኑይ", [
                _p("የሰኞ ምስጋና", "ኦ ድንግል ሆይ፣ አንቺ የብርሃን ደመና ነሽ፤ የጽድቅ ፀሐይን የተሸከምሽ። ለዓለም ሁሉ ብርሃንን አወጣሽ።"),
            ]),
        ],
    },
    {
        "title": "ገድለ ተክለ ሃይማኖት",
        "subtitle": "የጻድቁ ሕይወትና ተጋድሎ",
        "summary": "የኢትዮጵያዊው ጻድቅ የአቡነ ተክለ ሃይማኖት ሕይወት፣ ተአምራትና ተጋድሎ።",
        "author": "ትውፊተ ገድል",
        "language": "am",
        "tags": ["saints", "history", "devotion", "amharic"],
        "chapters": [
            _ch("ልደቱ", [
                _p("የጻድቁ መወለድ", "አቡነ ተክለ ሃይማኖት ከደጋግ ወላጆች ተወለዱ። ከሕፃንነታቸው ጀምሮ የእግዚአብሔር ጸጋ ይኖርባቸው ነበር፤ ለጸሎትም ይተጉ ነበር።"),
                _p("ተጋድሎ", "ጻድቁ በብሕትውና ሕይወት ጸንተው ለብዙ ዓመታት በጾምና በጸሎት ኖሩ። ብዙ ተአምራትንም በስማቸው እግዚአብሔር አደረገ።"),
            ]),
        ],
    },
    {
        "title": "መጽሐፈ ቅዳሴ",
        "subtitle": "የቅዳሴ ሥርዓት",
        "summary": "የኢትዮጵያ ኦርቶዶክስ ተዋሕዶ ቤተ ክርስቲያን የቅዳሴ ሥርዓቶችና ጸሎቶች።",
        "author": "የሐዋርያት ትውፊት",
        "language": "am",
        "tags": ["liturgy", "canon", "amharic"],
        "chapters": [
            _ch("ቅዳሴ ሐዋርያት", [
                _p("መግቢያ", "ካህኑ፦ እግዚአብሔር ከሁላችሁ ጋር ይሁን። ሕዝቡ፦ ከመንፈስህ ጋር። ልባችንን ወደ እግዚአብሔር እናንሣ።"),
            ]),
        ],
    },
    {
        "title": "ጸሎተ ምሕላ",
        "subtitle": "የንስሐና የምልጃ ጸሎት",
        "summary": "በመከራና በችግር ጊዜ የሚደረግ የንስሐና የምሕረት ጸሎት ስብስብ።",
        "author": "ትውፊተ ቤተ ክርስቲያን",
        "language": "am",
        "tags": ["prayer", "devotion", "amharic"],
        "chapters": [
            _ch("የንስሐ ጸሎት", [
                _p("ይቅርታ", "አቤቱ፣ እንደ ምሕረትህ ብዛት ማረኝ፤ እንደ ቸርነትህም ብዛት መተላለፌን ደምስስ። ከኃጢአቴ አጥራኝ፤ ንጹሕ ልብንም ፍጠርልኝ።"),
            ]),
        ],
    },
    # ------------------------- English titles -------------------------------
    {
        "title": "The Kebra Nagast",
        "subtitle": "The Glory of Kings",
        "summary": "A cornerstone Ethiopian text linking the Solomonic lineage, sacred kingship, and Christian tradition.",
        "author": "Traditional compilation",
        "language": "en",
        "tags": ["history", "canon", "english"],
        "chapters": [
            _ch("The Queen of Sheba", [
                _p("The Journey", "The Queen of the South heard of the wisdom of Solomon and journeyed to Jerusalem. She brought gifts of gold and spices, and tested him with hard questions, and he answered them all."),
                _p("The Covenant", "From the meeting of Solomon and the Queen came Menelik, and with him the Ark of the Covenant was carried to Ethiopia, where it is honoured to this day."),
            ]),
            _ch("The Lineage of Kings", [
                _p("Sacred Kingship", "The kings of Ethiopia traced their authority to the Solomonic line, joining the throne to the worship of God and the keeping of the Law."),
            ]),
        ],
    },
    {
        "title": "The Book of Enoch",
        "subtitle": "Ethiopic Recension",
        "summary": "An influential apocalyptic work preserved in full only in Ge'ez and kept within the Ethiopian canon.",
        "author": "Attributed to Enoch",
        "language": "en",
        "tags": ["canon", "history", "english"],
        "chapters": [
            _ch("The Words of Enoch", [
                _p("The Blessing", "The words of the blessing of Enoch, wherewith he blessed the elect and righteous who will be living in the day of tribulation, when all the wicked shall be removed."),
                _p("The Watchers", "And Enoch saw the vision of the Holy One in the heavens, and the angels showed him all things, and he understood the secrets of the stars and the seasons."),
            ]),
        ],
    },
    {
        "title": "Praises of Mary",
        "subtitle": "Weddase Maryam in English",
        "summary": "A daily cycle of Marian praise used in Ethiopian worship and personal devotion.",
        "author": "Liturgical compilation",
        "language": "en",
        "tags": ["marian", "liturgy", "prayer", "english"],
        "chapters": [
            _ch("Monday", [
                _p("Salutation", "Hail to you, O Virgin Mary, mother of the Light. The angels honour you, the prophets foretold you, and the faithful sing your praise without ceasing."),
                _p("Intercession", "O our Lady, intercede for us sinners before your Son. Lead us from the darkness of sin to the light, and shelter us beneath the shadow of your mercy."),
            ]),
        ],
    },
    {
        "title": "The Psalms of David",
        "subtitle": "Selected Psalms for Prayer",
        "summary": "A selection of the Psalms of David for daily prayer and praise, with brief notes.",
        "author": "King David the Prophet",
        "language": "en",
        "tags": ["psalms", "prayer", "english"],
        "chapters": [
            _ch("Psalm 23", [
                _p("The Lord is my Shepherd", "The Lord is my shepherd; I shall not want. He maketh me to lie down in green pastures; he leadeth me beside the still waters. He restoreth my soul."),
                _p("Through the Valley", "Yea, though I walk through the valley of the shadow of death, I will fear no evil: for thou art with me; thy rod and thy staff they comfort me."),
            ]),
        ],
    },
    {
        "title": "The Anaphora of the Apostles",
        "subtitle": "The Ethiopian Eucharistic Liturgy",
        "summary": "A central anaphora used in the celebration of the Eucharist across Ethiopian liturgical practice.",
        "author": "Apostolic liturgical tradition",
        "language": "en",
        "tags": ["liturgy", "canon", "english"],
        "chapters": [
            _ch("The Offering", [
                _p("Lift Up Your Hearts", "The priest says: The Lord be with you all. The people answer: And with your spirit. Lift up your hearts. We have lifted them to the Lord."),
            ]),
        ],
    },
    {
        "title": "The Synaxarium",
        "subtitle": "Lives of the Saints",
        "summary": "Daily commemorations of the saints and martyrs of the Church, ordered through the year.",
        "author": "Ethiopian Orthodox tradition",
        "language": "en",
        "tags": ["saints", "history", "devotion", "english"],
        "chapters": [
            _ch("Meskerem", [
                _p("The New Year", "On the first day of Meskerem the Church keeps the feast of the New Year and remembers John the Baptist, receiving the new year with thanksgiving."),
                _p("Saint Raphael", "Raphael the archangel is the guardian of the sick. The faithful entreat his intercession in time of illness and give thanks for healing."),
            ]),
        ],
    },
    {
        "title": "Commentary on the Gospel of John",
        "subtitle": "Traditional Homiletic Notes",
        "summary": "A teaching commentary emphasising Christology, faith, and the sacramental life.",
        "author": "Traditional commentary school",
        "language": "en",
        "tags": ["gospel", "teaching", "english"],
        "chapters": [
            _ch("In the Beginning", [
                _p("The Word", "In the beginning was the Word, and the Word was with God, and the Word was God. The commentary teaches that this opening declares the eternity and divinity of the Son."),
                _p("The Light", "In him was life; and the life was the light of men. And the light shineth in darkness; and the darkness comprehended it not."),
            ]),
        ],
    },
    {
        "title": "The Fetha Nagast",
        "subtitle": "The Law of the Kings",
        "summary": "A legal and ecclesiastical code that shaped civil and church practice in historical Ethiopia.",
        "author": "Translated and adapted tradition",
        "language": "en",
        "tags": ["canon", "history", "teaching", "english"],
        "chapters": [
            _ch("Church Order", [
                _p("On the Clergy", "The clergy are to serve the house of God in purity, steadfast in fasting and prayer, that they may be an example to the faithful."),
                _p("On Judgement", "Let judgement be given in truth and mercy. Let the judge show no partiality, but judge alike for the poor and for the rich."),
            ]),
        ],
    },
    {
        "title": "Dersane Mikael",
        "subtitle": "Homily of Saint Michael",
        "summary": "A beloved Ethiopian homily on the intercession of the archangel Michael and spiritual perseverance.",
        "author": "Homiletic tradition",
        "language": "en",
        "tags": ["saints", "devotion", "teaching", "english"],
        "chapters": [
            _ch("The Archangel", [
                _p("Prince of the Host", "Michael is the prince of the heavenly host. He stands before God and intercedes for the children of men, and overcomes the enemy."),
            ]),
        ],
    },
    {
        "title": "The Miracles of Mary",
        "subtitle": "Selections from Ethiopian Tradition",
        "summary": "Narratives of compassion and deliverance associated with the intercession of Saint Mary.",
        "author": "Traditional narratives",
        "language": "en",
        "tags": ["marian", "devotion", "english"],
        "chapters": [
            _ch("The Poor Man", [
                _p("A Cry for Help", "A poor man, overwhelmed with trouble, prayed to our Lady. She heard his plea and delivered him from his distress, and he gave thanks all his days."),
            ]),
        ],
    },
    {
        "title": "Prayer Book of the Hours",
        "subtitle": "The Canonical Hours",
        "summary": "Structured prayers for morning, noon, evening, and night in monastic and lay devotion.",
        "author": "Liturgical tradition",
        "language": "en",
        "tags": ["prayer", "liturgy", "devotion", "english"],
        "chapters": [
            _ch("Morning Prayer", [
                _p("At Dawn", "At the rising of the sun we give thanks to God who has kept us through the night, and we ask his guidance for the labours of the day."),
            ]),
        ],
    },
    {
        "title": "The Acts of the Apostles",
        "subtitle": "Ethiopian Study Edition",
        "summary": "The narrative of the apostolic mission and the growth of the early Church, prepared for study.",
        "author": "Biblical canon",
        "language": "en",
        "tags": ["gospel", "teaching", "history", "english"],
        "chapters": [
            _ch("Pentecost", [
                _p("The Spirit Descends", "When the day of Pentecost was fully come, they were all with one accord in one place, and there came a sound from heaven as of a rushing mighty wind."),
                _p("The Ethiopian Eunuch", "Philip met the Ethiopian official reading the prophet Isaiah, explained the Scripture to him, and baptised him; and he went on his way rejoicing."),
            ]),
        ],
    },
    {
        "title": "The Didaskalia",
        "subtitle": "Church Order and Instruction",
        "summary": "Church discipline, clergy conduct, and pastoral instruction in a historic Ethiopian context.",
        "author": "Early church tradition",
        "language": "en",
        "tags": ["canon", "teaching", "english"],
        "chapters": [
            _ch("Pastoral Care", [
                _p("The Shepherd", "Let the bishop care for the flock as a good shepherd, seeking the lost, binding the broken, and feeding all with the word of truth."),
            ]),
        ],
    },
    {
        "title": "The Covenant of Mercy",
        "subtitle": "Kidane Mehret",
        "summary": "A devotional text centred on mercy, intercession, and the covenant given to Saint Mary.",
        "author": "Traditional Ethiopian text",
        "language": "en",
        "tags": ["marian", "prayer", "devotion", "english"],
        "chapters": [
            _ch("The Covenant", [
                _p("A Promise of Mercy", "The covenant of mercy is the promise that those who call upon the name of our Lady in faith shall find help and intercession in their need."),
            ]),
        ],
    },
]


# Extra readers to populate per-user study data.
READERS = [
    ("reader@localhost", "Reader", "readerreader", "en"),
    ("abebe@localhost", "Abebe Kebede", "abebeabebe1", "am"),
    ("selam@localhost", "Selam Tesfaye", "selamselam1", "am"),
    ("john@localhost", "John Mark", "johnjohn123", "en"),
]


class Command(BaseCommand):
    help = "Seed ~30 realistic published books plus data for every backend feature."

    def add_arguments(self, parser):
        parser.add_argument("--count", type=int, default=len(BOOKS),
                            help=f"How many books to seed (max {len(BOOKS)}).")

    def handle(self, *args, **options):
        count = max(1, min(int(options["count"]), len(BOOKS)))
        if is_object_storage_configured():
            try:
                ensure_bucket()
            except Exception as exc:  # pragma: no cover - dev convenience
                self.stderr.write(self.style.WARNING(f"ensure_bucket skipped: {exc}"))

        admin = self._admin()
        readers = self._readers()
        tags = self._tags()

        books = self._books(admin, tags, count)
        self._legal(admin, readers)
        self._study(readers, books)

        self.stdout.write(self.style.SUCCESS(
            f"seed_demo_content: complete — books={len(books)}, tags={len(tags)}, "
            f"users={1 + len(readers)}"
        ))

    # -- users ---------------------------------------------------------------
    def _admin(self):
        admin, _ = User.objects.get_or_create(
            email="admin@localhost",
            defaults={"display_name": "Admin", "is_staff": True, "is_superuser": True, "role": "admin"},
        )
        admin.is_staff = admin.is_superuser = True
        admin.role = "admin"
        admin.display_name = admin.display_name or "Admin"
        admin.set_password("adminadminadmin")
        admin.save()
        return admin

    def _readers(self):
        out = []
        for email, name, pw, lang in READERS:
            u, _ = User.objects.get_or_create(
                email=email,
                defaults={"display_name": name, "role": "reader", "preferred_ui_language": lang},
            )
            u.display_name = u.display_name or name
            u.role = "reader"
            u.preferred_ui_language = lang
            u.set_password(pw)
            u.save()
            ReminderPreference.objects.get_or_create(
                user=u,
                defaults={"enabled": True, "hour_utc": 6, "minute_utc": 0, "weekdays_only": False},
            )
            out.append(u)
        return out

    # -- tags ----------------------------------------------------------------
    def _tags(self):
        tags = {}
        for slug, label in TAGS.items():
            tag, _ = Tag.objects.get_or_create(slug=slug, defaults={"label": label})
            if tag.label != label:
                tag.label = label
                tag.save(update_fields=["label"])
            tags[slug] = tag
        return tags

    # -- books + publish -----------------------------------------------------
    def _books(self, admin, tags, count):
        published = []
        for idx, data in enumerate(BOOKS[:count], start=1):
            book, created = Book.objects.get_or_create(
                title=data["title"],
                defaults={
                    "subtitle": data["subtitle"],
                    "summary": data["summary"],
                    "author_compiler": data["author"],
                    "primary_language": data["language"],
                    "script_tags": data["tags"],
                    "created_by": admin,
                },
            )
            book.subtitle = data["subtitle"]
            book.summary = data["summary"]
            book.author_compiler = data["author"]
            book.primary_language = data["language"]
            book.script_tags = data["tags"]
            book.created_by = book.created_by or admin
            book.chapters_draft = data["chapters"]
            book.save()

            # tag links
            for slug in data["tags"]:
                tag = tags.get(slug)
                if tag:
                    BookTag.objects.get_or_create(book=book, tag=tag)

            # publish (creates revision, uploads content, builds chapter/page/index)
            already = book.published_revision is not None and BookPage.objects.filter(
                revision=book.published_revision
            ).exists()
            if already:
                self.stdout.write(f"[{idx}/{count}] already published: {book.title}")
                published.append(book)
                continue

            outcome = publish_book(book, admin)
            if not outcome.ok:
                self.stderr.write(self.style.WARNING(
                    f"[{idx}/{count}] publish failed for {book.title}: {outcome.error}"
                ))
                continue
            book.refresh_from_db()
            published.append(book)
            pages = BookPage.objects.filter(revision=book.published_revision).count()
            self.stdout.write(f"[{idx}/{count}] published: {book.title} ({pages} pages)")
        return published

    # -- legal ---------------------------------------------------------------
    def _legal(self, admin, readers):
        now = timezone.now()
        docs = []
        for doc_type in ("terms", "privacy"):
            doc, _ = LegalDocument.objects.get_or_create(
                doc_type=doc_type,
                version=1,
                defaults={
                    "content_url": f"https://example.org/legal/{doc_type}/v1",
                    "effective_at": now - timedelta(days=90),
                },
            )
            docs.append(doc)
        for u in [admin, *readers]:
            for doc in docs:
                LegalAcceptance.objects.get_or_create(
                    user=u, legal_document=doc,
                    defaults={"accepted_at": now - timedelta(days=10)},
                )

    # -- study suite ---------------------------------------------------------
    def _study(self, readers, books):
        if not books:
            return
        now = timezone.now()
        for r_idx, user in enumerate(readers):
            # pick a few books for this user
            picks = [books[(r_idx + n) % len(books)] for n in range(min(4, len(books)))]

            folder, _ = StudyFolder.objects.get_or_create(
                user=user, name="የእኔ ጥናት / My Study",
            )

            for b_idx, book in enumerate(picks):
                rev = book.published_revision
                first_page = BookPage.objects.filter(revision=rev).order_by("page_number").first()
                chapter_key = first_page.chapter.chapter_key if first_page and first_page.chapter else ""
                page_no = first_page.page_number if first_page else 1
                snippet = (first_page.text_plain[:120] if first_page else book.summary[:120])

                bookmark, _ = UserBookmark.objects.get_or_create(
                    user=user, book=book, revision=rev, page_number=page_no,
                    defaults={
                        "chapter_key": chapter_key,
                        "label": f"{book.title} — {('ምልክት' if user.preferred_ui_language == 'am' else 'Bookmark')}",
                        "snippet": snippet,
                    },
                )
                highlight, _ = UserHighlight.objects.get_or_create(
                    user=user, book=book, revision=rev, page_number=page_no,
                    start_offset=0, end_offset=min(40, len(snippet) or 40),
                    defaults={
                        "chapter_key": chapter_key,
                        "excerpt": snippet[:80],
                        "color": ("yellow", "green", "blue", "pink")[b_idx % 4],
                    },
                )
                note, _ = UserNote.objects.get_or_create(
                    user=user, book=book, revision=rev, linked_highlight=highlight,
                    defaults={
                        "chapter_key": chapter_key,
                        "page_number": page_no,
                        "body": ("ይህን ክፍል መልሼ ላጠና / Revisit this section"
                                 if user.preferred_ui_language == "am"
                                 else "A note to revisit this passage in study."),
                    },
                )
                UserReadingProgress.objects.update_or_create(
                    user=user, book=book,
                    defaults={
                        "revision": rev, "chapter_key": chapter_key, "page_number": page_no,
                        "progress_percent": (15 + b_idx * 20) % 100,
                    },
                )
                ReaderEvent.objects.get_or_create(
                    user=user, book=book, event_name="page_view", page_number=page_no,
                    defaults={"revision": rev, "chapter_key": chapter_key,
                              "payload": {"source": "seed", "ms": 4200}},
                )
                # link the three study items into the folder
                StudyFolderEntry.objects.get_or_create(
                    folder=folder, item_type=StudyFolderEntry.ItemType.BOOKMARK, item_id=bookmark.id)
                StudyFolderEntry.objects.get_or_create(
                    folder=folder, item_type=StudyFolderEntry.ItemType.HIGHLIGHT, item_id=highlight.id)
                StudyFolderEntry.objects.get_or_create(
                    folder=folder, item_type=StudyFolderEntry.ItemType.NOTE, item_id=note.id)

            # daily reading plan across the picked books
            plan, _ = DailyReadingPlan.objects.get_or_create(
                user=user, title=("የ7 ቀን ንባብ / 7-Day Reading"
                                  if user.preferred_ui_language == "am" else "7-Day Reading Plan"),
                defaults={"is_active": True},
            )
            for day, book in enumerate(picks, start=1):
                rev = book.published_revision
                fp = BookPage.objects.filter(revision=rev).order_by("page_number").first()
                item, _ = DailyReadingPlanItem.objects.get_or_create(
                    plan=plan, day_index=day, book=book,
                    chapter_key=(fp.chapter.chapter_key if fp and fp.chapter else ""),
                    page_start=(fp.page_number if fp else 1),
                    page_end=(fp.page_number if fp else 1),
                    defaults={"note": f"Day {day}: {book.title}"},
                )
                StudyReminder.objects.get_or_create(
                    user=user, plan=plan, plan_item=item,
                    scheduled_for=now + timedelta(days=day, hours=6),
                    defaults={
                        "message": (f"ዛሬ {book.title} አንብብ" if user.preferred_ui_language == "am"
                                    else f"Time to read {book.title}"),
                        "status": StudyReminder.Status.PENDING,
                    },
                )
