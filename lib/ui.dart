import 'package:flutter/material.dart';
import 'package:havadurumuuygulamasi/weatherAPI.dart';
import 'package:path_provider/path_provider.dart';
import 'weatherAPI_specialFunctions.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui' as ui;
import 'package:dropdown_textfield/dropdown_textfield.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
//Kaç saniyede bir hava durumu bilgilerinin güncelleneceği Duration.

const Duration WeatherDataStreamDuration = const Duration(seconds: 5);
DateFormat DefaultDateFormat = DateFormat.yMMMMEEEEd("tr_TR");

const String RuzgarYonImageUrl =
    "https://mgm.gov.tr/Images_Sys/main_page/ryon-gri.svg";

const LinearGradient DefaultGradientColor = LinearGradient(
    begin: Alignment(0, -0.6),
    end: Alignment(0, 1),
    colors: <Color>[const Color(0xff001a31), Colors.greenAccent]);

BoxShadow DefaultBoxShadow = BoxShadow(
  color: Colors.black.withOpacity(0.4),
  spreadRadius: 5,
  blurRadius: 16,
  offset: Offset(0, 3), // changes position of shadow
);

ThemeData BaseThemeData = ThemeData(
    colorScheme: ColorScheme.light(),
    inputDecorationTheme: InputDecorationTheme(
        labelStyle: TextStyle(color: Colors.blue),
        focusedBorder: UnderlineInputBorder(
          borderSide: BorderSide(style: BorderStyle.solid, color: Colors.blue),
        )),
    textTheme: TextTheme(
      displayLarge: const TextStyle(
          fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
      // ···
      bodySmall: GoogleFonts.lato(
        fontSize: 30,
        fontStyle: FontStyle.normal,
        color: Colors.red,
      ),
      titleLarge: GoogleFonts.lato(
        fontSize: 30,
        fontStyle: FontStyle.normal,
        color: Colors.red,
      ),
      bodyMedium: GoogleFonts.merriweather(),
      displaySmall: GoogleFonts.pacifico(),
    ),
    appBarTheme: AppBarTheme(backgroundColor: Colors.green),
    navigationBarTheme: NavigationBarThemeData());
/*
class HavaDurumuApp extends StatelessWidget {
  const HavaDurumuApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}*/

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();

}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin  , WidgetsBindingObserver {
  int _currentPageIndex = 0;
  List<DropDownValueModel> AllTurkeyCountriesWithCounties = [];
  final SingleValueDropDownController _searchTextFieldController =
      SingleValueDropDownController();

  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 500),
    vsync: this,
  );

  @override
  void initState() {
    WidgetsBinding.instance!.addObserver(this);

    for (var i in AllCountryCounty) {
      //Tüm ilçe il adı ne varsa hepsini textfield'ın arama kısmına güzelce ekliyoruz.
      for (var k in i.counties)
        AllTurkeyCountriesWithCounties.add(DropDownValueModel(
            name: i.name + " " + k, value: i.name + " " + k));
    }
  }
  @override
  void dispose(){
    WidgetsBinding.instance!.removeObserver(this);

    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused) {
    Future(() async{print(await APPContext.Save());}).then((value) => null);

    }

  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Demo',
        debugShowCheckedModeBanner: false,
        theme: BaseThemeData, home : Scaffold(
        floatingActionButton: FloatingActionButton(
        onPressed: () {
        Future(() async{
        var pair = await GetCurrentLocationName();
        if (pair != null)
          await APPContext.SetCountryWeatherData(pair.returnValue.key, pair.returnValue.value);});

    } ,
            backgroundColor: Colors.transparent,
         child :   const Icon(Icons.location_on)),

      bottomNavigationBar: Container(
          decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                Colors.greenAccent,
                const Color(0xff001a31)
              ])),
          child: NavigationBar(
            onDestinationSelected: (int index) {
              setState(() {
                _currentPageIndex = index;
              });
            },
            indicatorColor: Colors.greenAccent.shade400,
            backgroundColor: Colors.transparent,
            height: 60,
            selectedIndex: _currentPageIndex,
            destinations: const <Widget>[

              NavigationDestination(
                selectedIcon: Icon(Icons.home),
                icon: Icon(
                  Icons.home_outlined,
                  color: Colors.white,
                ),
                label: 'Ana Sayfa',
              ),
              NavigationDestination(
                icon: Icon(
                  Icons.format_paint,
                  color: Colors.white,
                ),
                label: 'Koyu Tema',
              ),
            ],
          )),
      appBar: AppBar(
        flexibleSpace: Container(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
              Colors.greenAccent,
              const Color(0xff001a31)
            ]))),
        title: Center(
            child: Text(
          "Hava Durumu",
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w200,
            color: Colors.white,
          ),
        )),
      ),
      body: Center(
        child: Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 3,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: 40),
                    padding: EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: DefaultGradientColor,
                      boxShadow: [DefaultBoxShadow],
                    ),
                    child: Center(
                        child: Row(children: [
                      Expanded(
                          flex: 8,
                          child: DropDownTextField(
                              controller: _searchTextFieldController,
                              enableSearch: true,
                              dropDownList:
                                  this.AllTurkeyCountriesWithCounties)),
                      Spacer(),
                       IconButton(
                        color: Colors.white,
                        icon: Icon(Icons.search, size: 32),
                        onPressed: () {
                          //Şehir arama işlemi burada yapılıyor.
                          Future(() async {
                            if (_searchTextFieldController.dropDownValue !=
                                null) {
                              var splittedText = _searchTextFieldController
                                  .dropDownValue?.value
                                  .split(RegExp(r'\s+'));

                              await APPContext.SetCountryWeatherData(
                                  splittedText[0], splittedText[1]);
                              setState(() {

                              });
                            }
                            return null;
                          }).then((value) => null);
                        },
                      )
                    ])),
                  ),
                ),
                Spacer(),
                Expanded(
                    flex: 20,
                    child: AnimatedBuilder(
                        animation: _controller,
                        builder: (BuildContext context, Widget? child) {
                          var angle = Tween<double>(begin: 0, end: math.pi * 2)
                              .animate(_controller);

                          return Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.identity()
                                ..rotateY(angle.value),
                              child: Container(
                                  margin: EdgeInsets.symmetric(horizontal: 25),
                                  padding: EdgeInsets.symmetric(horizontal: 0),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    gradient: DefaultGradientColor,
                                    boxShadow: [DefaultBoxShadow],
                                  ),
                                  child: WeatherInformationWidget(
                                      this._controller)));
                        })),
              ],
            )),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    ));
  }
}

class WeatherInformationWidget extends StatefulWidget {
  late AnimationController _controller;

  WeatherInformationWidget(AnimationController this._controller, {super.key});

  @override
  State<WeatherInformationWidget> createState() => _WeatherInformationWidget();
}

class _WeatherInformationWidget extends State<WeatherInformationWidget> {
  late Stream<CountryWithWeatherData>
      _weatherStream; //Verilerimizin sürekli akışkanlığı sağlamamız için gerekli olan bir async generator.

  bool _FrontPage = true , ///Bu değişken biz cardı çevirdiğimiz zaman önünde ve arkasında iki farklı tasarım var ve bunu ayarlamak için kullanacağız.
      _isClickable = true;


  @override
  void initState() {
    super.initState();

    _weatherStream = Stream<CountryWithWeatherData>.periodic(
        WeatherDataStreamDuration, (count) {

      Future(() async {
        await APPContext.Save();
        if (await InternetConnectionChecker().hasConnection) {//Eğer bağlantı varsa tekrar güncel verileri MGM'den alsın.
          await APPContext.Update();
        }//Yoksa zaten eski  verileri kullanacak
        else{
          final snackBar = SnackBar(
            content: const Text('İnternet bağlantınız yok !'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // Some code to undo the change.
              },
            ),
          );

          // Find the ScaffoldMessenger in the widget tree
          // and use it to show a SnackBar.
          ScaffoldMessenger.of(context).showSnackBar(snackBar);

        }
      }).then((value) => null);
      return APPContext.GetCountryWeatherData().returnValue;
    });

    widget._controller.addStatusListener((status) {
      if (status == AnimationStatus.completed)this._isClickable = true;
    });

    widget._controller.addListener(() {
      //Animasyon bittiği zaman Card'ın tasarımını değiştirmek için kullanacağız.
      var angle = Tween<double>(begin: 0, end: math.pi * 2).animate(widget._controller);
      if (angle.value >= math.pi * 1.5 && this._isClickable) {
        this._isClickable = false;
        this._FrontPage = !this._FrontPage; //Eğer açımız 270'dereceden büyük ve eşitse ozaman tasarım değişecek.

      }

    });

  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<CountryWithWeatherData>(
        stream: this._weatherStream,
        builder: (BuildContext context,
            AsyncSnapshot<CountryWithWeatherData> snapshot) {
          if (snapshot.hasData) {
            var weatherData = snapshot.data!;

            List<Widget> widgets = [];
            List<Widget> body = [];

            DateFormat weekDayNameFrmt = DateFormat.EEEE("tr_TR");

            if (weatherData.daily != null && this._FrontPage) {//Eğer sayfanın ön yüzü ise widgets'a günlük verileri ekleyeceğiz.
              for (var predc in weatherData!.daily!) {
                String? weekName =
                DayOfWeekShortened[weekDayNameFrmt.format(predc!.dateTime!)];

                widgets.add(Expanded( child :  Container(child:
                    Column(children: [
                    SizedBox(
                        width: 32,
                        height: 32
                        ,
                      child :
                      APPContext.LoadImage(
                          MGMUrl.MGM_Images_URL.url + predc.event + ".svg") ??
                          CircularProgressIndicator()),
                      Text(weekName!),
                      Text(
                        predc.minTempature.toString() + "°c",
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        predc.maxTempature.toString() + "°c",
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ]))));
              }
            }
            else if (weatherData.hourly != null && !this._FrontPage){//Eğer sayfanın arka yüzü ise widgets'a saatlik verileri ekleyeceğiz.
              for (var predc in weatherData!.hourly!) {
                String? date =
                    weekDayNameFrmt.format(predc!.dateTime!) + "\n" +
               predc!.dateTime.hour.toString() + ".00 - " + (predc!.dateTime.hour + 3).toString() + ".00";

                widgets.add(
                   Row(children: [
                     SizedBox(width : 32 , height : 32 , child :
                         APPContext.LoadImage(
                          MGMUrl.MGM_Images_URL.url + predc.event + ".svg") )??
                          CircularProgressIndicator(),
                      const VerticalDivider(
                        width: 20,
                        thickness: 4,
                        indent: 20,
                        endIndent: 0,
                        color: Colors.grey,
                      ),
                      Text(date , style: TextStyle(color: Colors.white),),
                      Text(
                        predc.tempature.toString() + "°c",
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      /*Text(
                        predc.maxTempature.toString() + "°c",
                        style: TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold),
                      ),*/
                    ]));
              }
            }else {
              widgets.add(
                Container(child : Column(children :  [AutoSizeText("Veri bulunamadı !" , minFontSize: 16, maxFontSize: 64 , style: TextStyle(color : Colors.white , fontWeight: FontWeight.bold),) , CircularProgressIndicator()])));

            }


            if (this._FrontPage) {
            body =
              [
                Expanded( //Yukarı
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            DefaultDateFormat.format(
                                weatherData.latestSituation!.dateTime),
                            style: TextStyle(
                                color: Colors.white, fontSize: 24)),
                        Text(
                            textAlign: TextAlign.center,
                            weatherData.countryData!.name +
                                "\n" +
                                weatherData.countyName!,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 24))
                      ],
                    )),
                Expanded(flex : 2 , child : ListView(children : [
                Column(
                      children: [
                        SizedBox(width : 128 , height : 128 , child :
                            APPContext.LoadImage(  MGMUrl.MGM_Images_URL.url +
                            weatherData.latestSituation!.event + ".svg" ,
                            width: 164) ?? CircularProgressIndicator()),

                        Text(
                            EventCodeMap[weatherData
                                .latestSituation!.event] ??
                                "Belirtilemyen hadise adı !",
                            style: TextStyle(
                                fontWeight: FontWeight.w100,
                                color: Colors.white,
                                fontSize: 24)),
                        // Yüklenirken gösterilecek yükleme animasyonu

                        Text(
                            weatherData.latestSituation!.tempature
                                .toStringAsFixed(1) +
                                "°c",
                            style: TextStyle(
                                fontWeight: FontWeight.w100,
                                color: Colors.white,
                                fontSize: 40)),
                        Container(
                            child: Row(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [FittedBox(child :
                                  Text("Rüzgar Yönü ",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 20))),
                                  Transform.rotate(
                                      angle: weatherData!.latestSituation!
                                          .windDirectionAngle *
                                          math.pi /
                                          180,
                                      child:     SizedBox(
                                          width: 64,
                                          height: 64, child : APPContext.LoadImage(RuzgarYonImageUrl)) ?? CircularProgressIndicator() ),
                                  Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 15),
                                      child: AutoSizeText(
                                           minFontSize : 6,
                                          maxFontSize : 12,
                                          "${weatherData!.latestSituation!
                                              .windSpeed.toStringAsFixed(
                                              2)} km/s",
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight:
                                              FontWeight.bold))),
                                ]))
                      ],
                    ),
             Row( crossAxisAlignment: CrossAxisAlignment.center, children: widgets )
                // RaisedButton is deprecated and should not be used
                // Use ElevatedButton instead

                // child: RaisedButton(
                //   onPressed: () => null,
                //   color: Colors.green,
                //   child: Padding(
                //     padding: const EdgeInsets.all(4.0),
                //     child: Row(
                //       children: const [
                //         Icon(Icons.touch_app),
                //         Text('Visit'),
                //       ],
                //     ), //Row
                //   ), //Padding
                // ), //RaisedButton
                //SizedBox
              ]))];
            }else{

              body =
              [
                Expanded( //Yukarı
                    flex: 1,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                            DefaultDateFormat.format(
                                weatherData.latestSituation!.dateTime),
                            style: TextStyle(
                                color: Colors.white, fontSize: 24)),
                        Text(
                            textAlign: TextAlign.center,
                            weatherData.countryData!.name +
                                "\n" +
                                weatherData.countyName!,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 24))
                      ],
                    )),

                Expanded( //Orta
                    flex: 3,
                    child:ClipRect( child : ListView(children: widgets)))

                // RaisedButton is deprecated and should not be used
                // Use ElevatedButton instead

                // child: RaisedButton(
                //   onPressed: () => null,
                //   color: Colors.green,
                //   child: Padding(
                //     padding: const EdgeInsets.all(4.0),
                //     child: Row(
                //       children: const [
                //         Icon(Icons.touch_app),
                //         Text('Visit'),
                //       ],
                //     ), //Row
                //   ), //Padding
                // ), //RaisedButton
                //SizedBox
              ];
            }
            return
                //StreamBuilder<T>
                Card(
              elevation: 0,

              shadowColor: Colors.black,
              color: Color(0x0),

              child: Padding(
                  padding: const EdgeInsets.all(00.0),
                  child: InkWell(
                    splashColor: Colors.greenAccent.withAlpha(30),
                    onTap: () {
                      if (!this.widget._controller.isAnimating) {
                        this.widget._controller.reset();
                        this.widget._controller.forward();
                      }

                    },
                    child: Column(
                      children: body
                    ), //Column
                  )), //Padding
              //SizedBox
            );
          } else
            return Center(child : Column(mainAxisAlignment: MainAxisAlignment.center, children :  [CircularProgressIndicator() , AutoSizeText("Veri bekleniyor..." , minFontSize: 8 , maxFontSize: 128,style: TextStyle(color: Colors.white),) , ]));//Column
                   //Padding
        });
  }
}
