# Burgas restaurant import — 6 October 2026

**76 restaurant/food-place entries are prepared. They have not been inserted into Supabase yet.** A read-only check found zero shared restaurant rows. Browser control failed to start (CUA sandbox/kernel error), and no authenticated database administration CLI is available. No hosted data, accounts, passwords or permissions were changed by this preparation.

## Add the places to everyone's app

1. Open **add-burgas-restaurants.sql** beside this file and copy its entire contents.
2. In [your Supabase SQL Editor](https://supabase.com/dashboard/project/shodinaimhixnudqqgck/sql), create a **new query**, paste the SQL and click **Run**. Use this restaurant file, not the earlier hours-only script.
3. The final result is `restaurants_in_app`. With the empty starting table it should be **76**. Open Restaurants in the iPhone app and choose **Обнови местата**, or reopen the app. No new app build is needed if version 0.10.0 is already installed.

The import identifies your existing administrator by the email already used for this project, without modifying it. It creates no account, changes no password and grants no administrator role. It inserts into the existing `city_places` category **restaurants**, so places are shared across phones and admins can edit/delete them. Existing records are not overwritten. Stable IDs and a nearby same-name check make repeating the import safe; it preserves subsequent administrator edits. If you intentionally delete seeded places, do not run the seed again unless you want to restore them.

The optional opening-hours migration is included, so the restaurant script works whether or not the earlier hours script has been run. It does not remove toilets, reviews or favorites, and it keeps existing row-level access policies. If a confirmation dialog warns about schema/permission changes, review this exact script: it adds/validates the hours column and inserts restaurants, with no data-deletion statements.

## What was checked

- Individual [Go to Burgas food-place pages](https://info.gotoburgas.com/bg/plan/food_drink) provided names, addresses, website links and published map points. Only basic business facts were retained; no ratings, reviews, descriptions or photos were copied.
- Additional [Google Maps restaurant results](https://www.google.com/maps/search/restaurants%2BBurgas), [seaside results](https://www.google.com/maps/search/Dinner%2Bat%2BThe%2BSea%2BTerrace%2C%2BBurgas%2C%2BBulgaria) and [central listings](https://www.google.com/maps/search/Dinner%2Bat%2BThe%2BRoom%2C%2BBurgas%2C%2BBulgaria) were used to check selected business identities/addresses. Google's cached “open now” indicators were not imported as live facts. This was public-page research, not a Google Places API integration or complete Google Maps export.
- Restaurant-owned sites and map links resolved the incorrect directory pins for **GOTi Zornitsa** and **Vkusno**. Neptun's conflicting directory/owner-map points were replaced with the Central Beach point corroborated by MyBurgas and restaurant.bg. **Kamynite** in Sarafovo uses the exact place coordinates in its own Google Maps link.
- Opening hours are filled only for **GOTi Zornitsa**, **Vkusno**, **Neptun** and **Kamynite**, using their published restaurant schedules. Other hours remain unknown. Happy's official pages contain conflicting schedules, so its hours were not guessed.
- Entries outside the selected Burgas city area, missing coordinates, known address/pin conflicts, and duplicates such as Diverso/Chadara were excluded. This is a source-checked starting catalogue, **not every restaurant in Burgas**, a field survey, or a guarantee that every listing is still trading.

The detailed audit is in **burgas-restaurants-sources.json**. A Google navigation URL alone is not proof of independent Google verification; only explicit cross-check/source fields document that verification. Owner-published map embeds for GOTi and Vkusno are recorded as additional source evidence. The original iOS backup and web app are unchanged.

## Validation

- All 76 records decode and pass the app's actual `CommunityPlace` validation; coordinates are within the selected city bounds and unknown hours remain unknown.
- The generated SQL contains exactly the same records as `burgas-restaurants.json` and passes PostgreSQL syntax parsing (15 statements).
- Stable-ID repeat-import and preservation of administrator edits passed an in-memory data simulation. This is not a hosted PostgreSQL/RLS test; execution in your database and cross-phone appearance remain pending.
- Regenerate with `python3 Backend/build-restaurant-import.py` from the native project root after reviewing any changes to the JSON catalogue. This generator does not fetch websites or run SQL.

## Prepared places

| Place | Address | Source |
|---|---|---|
| Ambra bar & dinner | Бул. “Сан Стефано” 129 | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/ambra-bar-dinner) |
| Bistro Roma | Бургас, ул. Сердика 2 | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/bistro-roma) |
| BMS Българска кухня | ул. Сливница 21, Център, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/bms-bulgarian-cuisine) |
| Cachot Kitchen & Bar | ул. Райна Княгиня 15, Бургас Център | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/cachot-kitchen-bar) |
| Flora Bar & Grill | Бургас, бул. Даме Груев 2, ниво 2 - Комплекс Central Park Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/flora-bar-grill) |
| GOTi Family & Kitchen — Зорница | ж.к. Зорница 78, 8018 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/goti) |
| Happy Bar & Grill — Лазур | ж.к. Лазур, кв. 41, между бл. 5 и бл. 7, Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/happy-bar-grill) |
| KAMYNITE pizza \| bar \| dinner | ул. Буревестник 4, кв. Сарафово, Бургас | [Listing](https://kamynite.bg/bg/about) |
| La Ferme Steakhouse | бул. Даме Груев 16, партер вход откъм площада на Central Park, Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/la-ferme-steakhouse) |
| Manjari | Burgas Center, ul. "Kont Androvanti" 9, 8000 Burgas | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/manjari-) |
| Medusa | Лазур, ul. "Adam Mickiewicz" 7, 8000 Burgas | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/medusa-) |
| Opera Garden | ул. Любен Каравелов 36, Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/opera) |
| Parallel Lounge Burgas | гр. Бургас, Приморски парк Обект позиция - E26 H1, Моркса градина Северен паркинг | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/parallel-lounge-burgas) |
| Ponzu Sushi | Burgas Center, ul. "Makedonia" 17, 8000 Burgas, Bulgaria | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/ponzu-sushi) |
| Sale & Pepe | Комплекс Перла, блок 5, ж.к. Зорница | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/sale-pepe) |
| Ti Bar & Kitchen | улица Силистра №4 | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/ti-bar-kitchen) |
| TRE | гр. Бургас, ул. Трайко Китанчев 26 | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/tre) |
| Бирария Даляна | 8014 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/dalyana-brewery) |
| Бистро "Алегро" | Васил Априлов 14, Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/bistro-allegro) |
| Бистро Lazuro | ж.к. Лазур, ул. Копривщица 15, 8001 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/bistro-lazuro) |
| Бистро Белека | ж.к. Изгрев, бл. 109, 8008 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/bistro-beleka) |
| Бистро Гилзата | ж.к. Възраждане, ул. Сливница 11-13, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/bistro-gilzata) |
| Бистро Ронер | Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/bistro-roner) |
| Бистро Тропикана | 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/bistro-tropicana) |
| Бистро Уест | Парк Езеро, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/bistro-west) |
| бистро ЧАДЪРА | Приморски парк - Бургас, до Летен театър | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/bistro-chadar) |
| Ботега | ж.к. Лазур 77, 8001 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/botega) |
| Вкусно | ж.к. Изгрев, бл. 133, 8008 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/delicious) |
| Гирос | ул. Сливница 2, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/gyros) |
| Гранд'Италия | ул. Перущица, 8001 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/granditalia) |
| Грация Пицария | ул. Въстаническа 22, Меден рудник, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/gratsiya-pizzaria) |
| Грог | ж.к. Славейков 135, 8005 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/grog) |
| Гролш | ул. 24-ти Пехотен Черноморски полк 12, Приморски парк, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/grolsh) |
| Даляна | Пристанищен комплекс, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/dalyana) |
| ДАС Марина Бургас | Морска гара Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/das-marina-burgas) |
| Джоли Роджър | Морска гара Бургас, Пристанищен комплекс, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/jolly-roger) |
| Джърси | ж.к. Братя Миладинови, ул. Вардар 27, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/jersy) |
| Диверсо | ул. „Съединение“ №7 | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/diverso-restaurant-bar) |
| Док 5 | Пристанищен комплекс, МАРИНА, 8000 | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/dock-5) |
| Домашна кухня Детелина | Център, ул. Марагидик 16, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/detelina-home-kitchen) |
| Етно ресторант | ул. Михаил Лермонтов 7, Център, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/ethno-restaurant) |
| Замъка | ж.к. Изгрев 701, 8008 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/the-castle) |
| Златна Рибка | ул. "Цар Симеон I" 3, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/golden-fish) |
| Инканто | пл. Баба Ганка 4, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/incanto) |
| Искендер Кебаб | кв. Здраве, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/iskender-kebab) |
| Кардамон | Център, бул. Алеко Богориди 27, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/cardamon) |
| Кинг Конг Бургер | Център, ул. "Силистра" 1, 8001 | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/king-kong-burger) |
| Китайска Луна | ул. "Константин Фотинов" 27, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/chinese-moon) |
| Китайска храна Тройката | Център, ул. Сливница 2, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/chinese-food-troykata) |
| Криго | ж.к. Меден рудник 248, 8011 Меден Рудник | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/krigo) |
| Ла Флор Бар & Грил | ж.к. Лазур, ул. Велико Търново 11, 8001 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/la-flor-bar-grill) |
| Лично | ул. Булаир 27, Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/lichno) |
| Мамалига | ж.к. Зорница, бл. 163, 8008 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/mamaliga) |
| Маркето | бул.Демокрация, бл.117, | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/pjNmA4bftbxrtyUn1wQK) |
| Мейзънс Стрийт | ж.к. Славейков бл. 60, 8005 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/maisons-street) |
| Механа Балканска среща | ж.к. Петко Р. Славейков, бл. 72, 8010 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/tavern-balkan-meeting) |
| Морски сговор | рибарско селище Клуб-Морски сговор, 8014 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/sea-conspiracy) |
| Нори | бул. Алеко Богориди 38, Център, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/nori) |
| Ореха | Алеко Богориди 51, 8000 | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/oreha) |
| Пиаца Гранде | ул. "Морска" 12А, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/piazza-grande) |
| Пица Шоп | ул. Сливница 4, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/pizza-shop) |
| Пицария Monte Pizza | Гр. Бургас ж.к. Възраждане ул. Ивайло 24 | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/pizzeria-monte-pizza) |
| При музея | ул. Антим I 28, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/at-the-museum) |
| Реверанс | ж.к. Изгрев, бл. 144, 8008 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/reverence) |
| Ресторант 8 Mama's | ул. Булаир 35 | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/restaurant-8-mamas) |
| Ресторант Авеню Делукс | Северна промишлена зона, бул. Транспортна 53, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/restaurant-avenue-deluxe) |
| Ресторант България - A La Carte Mezzanine | Бургас, ул. Александровска 21, Бизнес хотел България | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/restaurant-bulgaria-a-la-carte-mezzanine) |
| Ресторант Капана | 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/kapana-restaurant) |
| Ресторант Нептун | Централен плаж, Приморски парк, Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/neptune-restaurant) |
| Романс пица | парк Славейков, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/romance-pizza) |
| Сезам | Северна индустриална зона, бул. Стефан Стамболов, 8001 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/sezam) |
| Теньова къща | ж.к. Петко Р. Славейков, 8005 | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/tavern-tenyos-house) |
| Чайнатаун | ж.к. Изгрев 160, 8008 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/chinatown) |
| Черно и бяло | ж.к. Лазур, 8001 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/black-and-white) |
| Юнашка мръвка | бул. Транспортна 35, Северна промишлена зона, 8008 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/heros-crumb) |
| Явка Фуд Бар | ул. "Цар Симеон I" 83, 8000 Бургас | [Listing](https://info.gotoburgas.com/bg/plan/food_drink/yavka-food-bar) |
