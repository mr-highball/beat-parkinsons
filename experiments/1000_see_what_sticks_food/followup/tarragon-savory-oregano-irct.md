# Iranian registry and thesis follow-up

The November 13, 2026 run used the existing native Free Pascal IRCT collector. Exact unfielded and `@irct_id:` searches each returned one row for IRCT2015072215860N2 and IRCT20211203053264N1. Additional searches returned seven records for `Satureja hortensis`, four for `tarragon`, twenty for `مرزه` and five for `ترخون`. The named English and Persian details folders retain official HTML. The XML links were obtained from the HTML download menu and saved as `irct-<page>.xml`. The two original accessions did not occur in the existing Parkinson-focused IRCT and WHO snapshots. The WHO accession details each timed out after 20 seconds with no bytes.

| IRCT accession | Official page | Registered | Publication or remaining trail |
| --- | --- | --- | --- |
| IRCT2013112515542N1 | [14789](https://irct.ir/trial/14789) | 2013-12-17 | 2015 Yazd oral dried savory leaf powder report, matched by investigator, cohort size and arm details. Figure 1 and Table 2 checked. |
| IRCT2015072215860N2 | [14997](https://irct.ir/trial/14997) | 2015-07-30 | 2018 reflux paper verified the accession. DOI publisher route and legacy IRCMJ path did not supply a fresh copy; full author-upload was already reviewed. |
| IRCT2016061813691N7 | [13482](https://irct.ir/trial/13482) | 2016-08-15 | May 2018 pediatric chemotherapy mucositis paper verifies accession and ethics ID. Table 2 and Figures 1 and 2 checked. DOI publisher route was unavailable. |
| IRCT20211203053264N1 | [60390](https://irct.ir/trial/60390) | 2021-12-11 | September 2026 tarragon almond-oil study verifies accession and ethics ID. The public record labels registration prospective and displays enrollment 2021-12-18. Its title references Iranian year 1399 and the article describes 2020. |
| IRCT20220403054396N1 | [65857](https://irct.ir/trial/65857) | 2023-03-24 | Distinct tarragon sesame-oil trial. Searches for Farzane Shafiee / فرزانه شفیعی, Zahra Yonesi / زهرا یونسی, accession, title and IR.BUMS.REC.1401.350 did not locate outcomes. |
| IRCT20241115063712N1 | [80210](https://irct.ir/trial/80210) | 2025-04-14 | Dental injection pain. Searches by trial title, accession, IR.MAZUMS.REC.1403.278 and Amir Hossein Moddabi / امیرحسین مدبی did not locate outcomes. |

The 2026 tarragon article states that the trial arose from a Birjand University of Medical Sciences master’s thesis. Searches combined Soheila Abedpour / سهیلا عابدپور, Zahra Unesi / زهرا یونسی, Ahmad Nasiri / احمد نصیری, the exact Persian registry title `تاثیر موضعی عصاره روغنی ترخون بر شدت درد، خشکی و عملکرد فیزیکی مفصل زانو در بیماران مبتلا به استئوآرتریت مزمن`, the ethics code and the trial ID. Public indexes returned the journal article or unrelated records. IranDoc’s Ganj timed out and the Birjand medical university’s likely catalog domains could not be reached from the search interface. A public thesis text and defense date remain unverified.

Replay examples from the repository root:

```powershell
$experiment = 'experiments/1000_see_what_sticks_food'
$collector = "$experiment/build/irct-3.3.1-i386-win32/bin/foodexperiment.irct.exe"
$output = "$experiment/build/tarragon-savory-oregano"
& $collector search irct.ir "$output/irct-id-savory" IRCT2015072215860N2
& $collector search irct.ir "$output/irct-id-tarragon" IRCT20211203053264N1
& $collector detail irct.ir "$output/irct-english-details" 14997 60390 65857 80210 13482 14789
& $collector detail fa.irct.ir "$output/irct-persian-details" 14997 60390 65857 80210 13482 14789
```
