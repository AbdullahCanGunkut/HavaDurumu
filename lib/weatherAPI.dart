/*
* AUTHOR ABDULLAH CAN GUNKUT
* YEAR : 2024
* */

import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:havadurumuuygulamasi/ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as htmlParser;
import 'package:html/dom.dart';

import 'dart:async';
import 'dart:isolate';

import 'dart:convert';
import 'dart:typed_data';

import 'dart:ui' as ui;

import 'weatherAPI_specialFunctions.dart';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:pair/pair.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:vector_graphics/vector_graphics.dart';
import 'package:intl/intl.dart';

//Global olarak kullanılan değişkenler.
late dynamic AllCountryCountyMGM;

List<CountryData> AllCountryCounty = [];

const int MaxDayPredictionNum = 5; //Maksimun 5 tane gün tahmini yapıyor MGM.

///Geçersiz değerlerin büyülü numarası.
const double INVALID_MAGIC_PARAMETER = -9999;
const String dataBasePath = "WeatherData.db";
const String DefaultCountryName = "İstanbul";
const String DefaultCountyName = "Bakırköy";
const String DefaultSavedWeatherInformationName = "weatherInfo";

late WeatherAppContext APPContext;

/*MGM API Analizilerim
*merkezId -> her ilçelerin Primary key ve 1 - e çok ilişkide kullanacağımız en temel key.
*gunlukTahminIstNo-> Günlük tahmin için kullanılacak Primary kKey.
*saatlikTahminIstNo -> Saatlik thamin için kullanılacka Primary key.
 */

/*DataBase yapısı :
* 3 tablo oluşturuldu ve her biri WeatherData'nın classlarını temsil ediyor
* İlişkilendirilme için şu 3 key önemli : merkezId , gunlukTahminIstNo , saatlikTahminIstNo ve merkezId hariç diğer iki key merkezId'ye bağlı (Foreign Key).
*
*
* */

//MGM'den veri çekmek için kullanacağımız header.
const Map<String, String> CommonHeadersForHtppRequest = {
  "Accept": "application/json, text/plain, */*",
  "Accept-Encoding": "gzip, deflate, br",
  "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
  "Connection": "keep-alive",
  "Host": "servis.mgm.gov.tr",
  "Origin": " https://mgm.gov.tr",
  "Referer": "https://mgm.gov.tr/",
  "Sec-Fetch-Dest": "empty",
  "Sec-Fetch-Mode": "cors",
  "Sec-Fetch-Site": "same-site",
  "User-Agent":
      "Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36",
  "sec-ch-ua":
      "Not A(Brand\";v=\"99\", \"Google Chrome\";v=\"121\", \"Chromium\";v=\"121\"",
  "sec-ch-ua-mobile": "?1",
  "sec-ch-ua-platform": "Android"
};
//MGM'den svg dosyası indirmek için kullanacağımız header.
Map<String, String> CommonHeadersForHtppRequestImage = {
  'Accept':
      'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
  'Accept-Encoding': 'gzip, deflate, br',
  'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
  'Cache-Control': 'max-age=0',
  'Connection': 'keep-alive',
  'Host': 'mgm.gov.tr',
  'Sec-Fetch-Dest': 'document',
  'Sec-Fetch-Mode': 'navigate',
  'Sec-Fetch-Site': 'none',
  'Sec-Fetch-User': '?1',
  'Upgrade-Insecure-Requests': '1',
  'User-Agent':
      'Mozilla/5.0 (Linux; Android 6.0; Nexus 5 Build/MRA58N) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',
  'sec-ch-ua':
      '"Not A(Brand";v="99", "Google Chrome";v="121", "Chromium";v="121"',
  'sec-ch-ua-mobile': '?1',
  'sec-ch-ua-platform': '"Android"',
};

//Hangi url'ların yazdığımız kodlar tarafından çekileceği genel bir enum class.
enum MGMUrl {
  ///Belirtilen ilçeden alınacak olan meta bilgiler url. Aynı zamanda 1 - çok ilişkide kullanacağımız en temel veri ve özellike belirtiyorum merkezId Primary keydir.
  MGM_CountryCounty_URL("https://servis.mgm.gov.tr/web/merkezler/ililcesi?il="),

  ///İlçe hakkında anlık durum almak için kullanılan url.
  MGM_LatestSituation_URL(
      "https://servis.mgm.gov.tr/web/sondurumlar?merkezid="),

  ///Günlük bilgi almak için kulanılan url. (maksimun 5 gün)
  MGM_Daily_URL("https://servis.mgm.gov.tr/web/tahminler/gunluk?istno="),

  ///Saatlik bilgi almak için kullanılan url.
  MGM_Hourly_URL("https://servis.mgm.gov.tr/web/tahminler/saatlik?istno="),

  ///Tüm ilçeler hakkında bilgi almak için kullanılan url.
  MGM_AllCountryCounty_URL("https://servis.mgm.gov.tr/web/merkezler/iller"),

  ///İllerin ilçesi hakkında bilgi almak için kullanılan url.
  MGM_CountryCounties_URL(
      "https://servis.mgm.gov.tr/web/merkezler/ililcesi?il="),

  ///SVG dosyalarını (resimleri) almak için kullanılan url.
  MGM_Images_URL("https://mgm.gov.tr/images_sys/hadiseler/");

  final String url;

  const MGMUrl(this.url);
}

//Hava durumu json türleri.
enum MGMWeatherType {
  MGM_LatestSituation, //En son durum tahmini
  MGM_Daily, //Günlük tahminler (maksimun 5 gün)
  MGM_Hourly //Saatlik tahminler
}

//Hata kodları.
enum WeatherAppErrorCode {
  RequestError, //Eğer bir http request olumsuz bir yanıt alırsa.
  Exception, //Eğer herhangi bir excpetion catch olursa.
  InvalidArgument, //Eğer herhangi bir fonksiyon argümanı geçersiz olursa.
  InvalidMember, //Eğer herhangi bir sınıfın üyesi geçersiz ise.
  AnyError, //Eğer herhangi bir hata geldiyse.
  TypeError, //Eğer generic type veya herhangi bir tür istelinen türe dönüşemezse.
  Success //İşlem başarıyla biterse.
}

//Dosyadan veri almak için path türleri.
enum WeatherAppPathType {
  //Dosya yolu tipi.
  Direct, //Direkt olarak gerçek adres
  Relative, //Local dosya
  Url, //İnternet adresi
  Assets, //Assets dosyası
}

//Hava durumu uygulamamızda kullanacağımız resimlerin türleri.
enum WeatherAppImageType {
  Svg,

  ///Vektörel resim.
  Image,

  ///Rasterlenmiş resim (normal resim).
}

/*
*Tüm hava durumu işlemlerini yapacak olan context'miz.
*Hava durumlarının işlemlerini yöneten patronu olur kenidisi.
*Özellikleri : Verileri yönetme , bilgiler veya dosyalar eğer internet olmazsa otomatik olarak local dosyaya kaydetme , program bittiğinde tüm bilgileri yedekleme (SQLLite ile).
*
* */

final class WeatherAppContext {
  WeatherAppContext();

  final Map<String, SvgPicture> eventImages =
      {}; //Eğer bir resim aynı yerden yüklendiyse buradan direkt olarak alınır ve tekrar resim dosyadan yüklenmek zorunda kalmaz.

//Ekrana hangi hava durumu yansıyorsa onun verisini tutar ve private olmasındaki neden sadece WeatherAppContext tarafından set edilecek çünkü bunları yaparken arkada özel işlemler gerçekleşiyor.

  CountryWithWeatherData? _countryWeatherData;

  ///Yedek çıkarır local dosyaya.
  Future<WeatherAppError> Save() async {
    var dir = (await getApplicationDocumentsDirectory()).path + "/temp/";
    print("Dir ${dir}");
    try {
      Directory directory = Directory(dir);
      if (!(await directory.exists())) {
        // Directory yoksa oluştur
        await directory.create(recursive: true);
        print('$dir klasörü oluşturuldu');
      } else {
        print('$dir klasörü zaten mevcut');
      }

      if (this._countryWeatherData != null) {
        File file = File("${dir}${DefaultSavedWeatherInformationName}.json");
        await file.writeAsString(jsonEncode(this._countryWeatherData));
      }

      for (var image in this.eventImages.entries) {
        //MGM'den gelen svg dosyalarını depolayalım. Eğer internet olmazsa otomatik depolanacak.

        var splittedUrl =
            image.key.split(RegExp(r'/')); //Dosya yollarını parçalara ayıralım.
        var extensionUrl = splittedUrl[splittedUrl.length - 1]
            .split(RegExp(r'\.'))
            .last
            .toLowerCase();

        if ((extensionUrl == "png" || extensionUrl == "svg") == false)
          continue; //eğer bu dosyalardan biri değilse kayıt etmesin
        var request = await http.get(Uri.parse(image.key),
            headers:
                CommonHeadersForHtppRequestImage); //Tekrar dosyaları indirelim , güncel olanları.
        if (request.statusCode == 200) {
          File file = File("${dir}${splittedUrl[splittedUrl.length - 1]}");
          file.writeAsStringSync(ConvertUtf8(request.bodyBytes));
        }
      }

      return WeatherAppError();
    } catch (e) {
      return WeatherAppError(
          errorCode: WeatherAppErrorCode.Exception, what: e.toString());
    }
  }

  ///Yedeklenmiş verileri alır ve kendi verilerini o alınan verilere göre eşitler.
  ///Bu fonksiyon initalize_API tarafından kullanılır.
  Future<WeatherAppError> Load() async {
    var dir = (await getApplicationDocumentsDirectory()).path + "/temp/";
    print("Dir ${dir}");
    File file = File("${dir}/${DefaultSavedWeatherInformationName}.json");
    var connection = await InternetConnectionChecker().hasConnection;

    if (connection) {
      //Eğer internet varsa konumdan veri alsın yoksa eğer bir önceki havadurumu bilgileri dosyaları kayıtlı ise oradan alsın.
      var locationPair = await GetCurrentLocationName();
      if (locationPair.errorCode == WeatherAppErrorCode.Success)
        this.SetCountryWeatherData(
            locationPair.returnValue.key, locationPair.returnValue.value);
    } else if (file.existsSync()) {
      this._countryWeatherData =
          CountryWithWeatherData.fromJson(jsonDecode(file.readAsStringSync()));
      print(this._countryWeatherData.toString());

      //if (!connection) {//Tüm svg dosyalarını yükleyelim eğer internet bağlantısı yoksa.
      List<String> allFileNames = await getAllFileNames(dir);

      for (var i in allFileNames) {
        var extension = i.split(RegExp(r'\.'));
        if (extension.length > 0 &&
            extension[extension.length - 1].toLowerCase() == "svg") {
          var error = await loadImageFromPath(dir + i,
              pathType: WeatherAppPathType
                  .Direct); //Bu sefer shared imagesi parametre içine koymadık çünkü key'i özel olarak atamamızlazım url'a göre. Buradaki parametre olan dir , dosyayı temsil ediyor telefondaki.
          if (error.errorCode == WeatherAppErrorCode.Success) {
            if (i == "ryon-gri.svg")//Tüm güzelliği mahveden dosya. :D
              this.eventImages[RuzgarYonImageUrl] = error.returnValue;
            else
              this.eventImages[MGMUrl.MGM_Images_URL.url + i] = error.returnValue;
          }
        }
      }
      print(this.eventImages);
    }
    return WeatherAppError();
  }

  //
  Future<WeatherAppError> Update() async {
    if (_countryWeatherData != null &&
        _countryWeatherData?.countryData != null) {
      CountryWithWeatherData weatherData = CountryWithWeatherData();
      return await weatherData.fromRequest(
          this._countryWeatherData!.countryData!.name,
          this._countryWeatherData!.countyName!);
    }

    return WeatherAppError(
        errorCode: WeatherAppErrorCode.AnyError, what: "Duck !");
  }

/*MGM'den verilen il ve ilce adından direkt veri alma.*/
  static FutureOr<WeatherAppError> LoadWeatherDataFromMGM(
      String il, String ilce,
      {MGMWeatherType? weatherType}) async {
    weatherType ??= MGMWeatherType.MGM_LatestSituation;

    try {
      var countyData =
          await GetCountryCounties(il, ilce: ilce); //ilçe bilgisini alalım.

      if (countyData.errorCode != WeatherAppErrorCode.Success)
        return countyData;

      //Gönderilecek olan GET request'in en sonundaki eşitliğe gidecek olan string'i WeatherType göre belirler.
      String id = weatherType == MGMWeatherType.MGM_LatestSituation
          ? countyData.returnValue["merkezId"].toString()
          : weatherType == MGMWeatherType.MGM_Daily
              ? countyData.returnValue["gunlukTahminIstNo"].toString()
              : countyData.returnValue["saatlikTahminIstNo"].toString();

      var request = await http.get(
          Uri.parse((weatherType == MGMWeatherType.MGM_LatestSituation
                  ? MGMUrl.MGM_LatestSituation_URL.url
                  : weatherType == MGMWeatherType.MGM_Hourly
                      ? MGMUrl.MGM_Hourly_URL.url
                      : weatherType == MGMWeatherType.MGM_Daily
                          ? MGMUrl.MGM_Daily_URL.url
                          : "") +
              id),
          headers: CommonHeadersForHtppRequest);

      if (request.statusCode == 200) {
        var json = jsonDecode(ConvertUtf8(request.bodyBytes));
        switch (weatherType) {
          //Son hava durumu
          case MGMWeatherType.MGM_LatestSituation:
            json = json[0];

            return WeatherAppError(
                returnValue: WeatherData(
                    country: il,
                    county: ilce,
                    event: json["hadiseKodu"],
                    tempature: json["sicaklik"] is double
                        ? json["sicaklik"]
                        : json["sicaklik"] is int
                            ? json["sicaklik"].toDouble()
                            : INVALID_MAGIC_PARAMETER,
                    windSpeed: json["ruzgarHiz"] is double
                        ? json["ruzgarHiz"]
                        : json["ruzgarHiz"] is int
                            ? json["ruzgarHiz"].toDouble()
                            : INVALID_MAGIC_PARAMETER,
                    windDirectionAngle: json["ruzgarYon"] is int
                        ? json["ruzgarYon"]
                        : json["ruzgarYon"] is double
                            ? json["ruzgarYon"].toInt()
                            : INVALID_MAGIC_PARAMETER.toInt(),
                    dateTime: DateTime.parse(json["veriZamani"])));

          //Günlük tahminler
          case MGMWeatherType.MGM_Daily:
            List<WeatherDailyData> dtArray = [];
            json = json[0]; //ilk map'mizi alıyoruz.
            //Liste olarak kaydetmemiz lazım veriyi çünkü API 5 günlük tahmin veriyor bize.
            for (int i = 1; i <= MaxDayPredictionNum; i++) {
              var str = i.toString();
              dtArray.add(WeatherDailyData(
                  country: il,
                  county: ilce,
                  event: json["hadiseGun" + str],
                  tempature: INVALID_MAGIC_PARAMETER,
                  windSpeed: (json["ruzgarHizGun" + str]).toDouble(),
                  windDirectionAngle: json["ruzgarYonGun" + str] as int,
                  dateTime: DateTime.parse(json["tarihGun" + str]),
                  minTempature: json["enDusukGun" + str],
                  maxTempature: json["enYuksekGun" + str]));
            }
            return WeatherAppError(returnValue: dtArray);

          //Saatlik Havadurumu tahminleri
          case MGMWeatherType.MGM_Hourly:
            List<WeatherHourlyData> dtArray = [];

            json = json[0]["tahmin"];

            //Bunuda aynı şekilde liste olarak kayıt edeceğiz  ve
            for (int i = 1; i <= json.length; i++) {
              var str = i.toString();
              var obj = json[i -
                  1]; //Indeksler herzaman sıfırdan başlar bunu unutmayın :D (tabi bazı dillerde farklı olabilir)
              dtArray.add(WeatherHourlyData(
                  country: il,
                  county: ilce,
                  event: obj["hadise"],
                  tempature: obj["sicaklik"].toDouble(),
                  windSpeed: (obj["ruzgarHizi"]).toDouble(),
                  windDirectionAngle: obj["ruzgarYonu"] as int,
                  dateTime: DateTime.parse(obj["tarih"])));
            }
            return WeatherAppError(returnValue: dtArray);
        }
      }
    } catch (e) {
      return WeatherAppError(
          errorCode: WeatherAppErrorCode.Exception, what: e.toString());
    }

    return WeatherAppError(errorCode: WeatherAppErrorCode.RequestError);
  }

  /*Uygulamamızda kullanacağımız tüm resim verileri bu fonksiyondan kullanılacak.*/
  SvgPicture? LoadImage(String path,
      {WeatherAppPathType? type,
      double? width,
      WeatherAppImageType? imageType}) {
    type ??= WeatherAppPathType.Url;
    imageType ??= WeatherAppImageType.Svg;

    width ??= 16;

    Future(() async {
      var ret = await loadImageFromPath(path,
          sharedImages: this.eventImages,
          pathType: type,
          width: width,
          imageType: imageType);
    }).then((value) => null);

    return this.eventImages[path];
  }

  //_countryWeatherData'nın kopyasını döndürür.
  WeatherAppError GetCountryWeatherData() {
    if (this._countryWeatherData == null)
      return WeatherAppError(
          errorCode: WeatherAppErrorCode.InvalidMember,
          what: "Invalid member ! => private _countryWeatherData");

    return WeatherAppError(
        returnValue: CountryWithWeatherData(
            countryData: _countryWeatherData?.countryData,
            latestSituation: _countryWeatherData?.latestSituation,
            hourly: _countryWeatherData?.hourly,
            daily: _countryWeatherData?.daily,
            countyName: _countryWeatherData?.countyName));
  }

  //Context içindeki hava durumu bilgilerini günceller. (_countryWeatherData)
  Future<WeatherAppError> SetCountryWeatherData(String il, String ilce) async {
    if (this._countryWeatherData == null) {
      var obj = await CheckCountryName(il, ilce);
      if (obj == null)
        return WeatherAppError(
            errorCode: WeatherAppErrorCode.InvalidArgument,
            what:
                "Invalid arguments or argument ! => il: ${il} , ilce : ${ilce}");
      else
        this._countryWeatherData = CountryWithWeatherData();
    }
    return await this._countryWeatherData!.fromRequest(il, ilce);
  }
}

//weatherAPI' tarafından kullanılacak olan fonksiyonların genel olarak dönderdiği bir class.
final class WeatherAppError {
  late final String
      what; //Eğer bir exception catch olursa onun hangi exception olduğu burada belirlenir.
  late final WeatherAppErrorCode
      errorCode; //Fonksiyonumuzun hangi hatayla return ettiğinin belirlendği değişken.
  late final dynamic
      returnValue; //Eğer bir return değer varsa burada belirlenir.

  WeatherAppError(
      {String? what, WeatherAppErrorCode? errorCode, dynamic returnValue}) {
    this.errorCode = errorCode ?? WeatherAppErrorCode.Success;
    this.what = what ?? "";
    this.returnValue = returnValue;
  }

  @override
  String toString() {
    String returnText = " / Return Value : " +
        (this.errorCode == WeatherAppErrorCode.Success
            ? this.returnValue.toString()
            : "");
    return (this.errorCode == WeatherAppErrorCode.RequestError
            ? "Exception : " + this.what.toString()
            : "Error Code : " +
                this.errorCode.toString() +
                " / What : " +
                this.what.toString()) +
        returnText;
  }
}

///Hava durumuzun verisini tutan class'ımız.
final class WeatherData {
  late final String country;

  ///İl
  late final String county;

  ///İlçe
  late final String event;

  ///Hadise
  late final double tempature;

  ///Sıcaklık
  late final double windSpeed;

  ///Rüzgar hızı
  late final int windDirectionAngle;

  ///Rüzgar açısı derecesi
  late final DateTime dateTime;

  ///Tarih

  WeatherData(
      {String? country,
      String? county,
      String? event,
      double? tempature,
      double? windSpeed,
      int? windDirectionAngle,
      DateTime? dateTime}) {
    this.country = country ?? "";
    this.county = county ?? "";
    this.event = event ?? "";
    this.tempature = tempature ?? INVALID_MAGIC_PARAMETER;
    this.windSpeed = windSpeed ?? INVALID_MAGIC_PARAMETER;
    this.windDirectionAngle =
        windDirectionAngle ?? INVALID_MAGIC_PARAMETER.toInt();
    this.dateTime = dateTime ?? DateTime.now();
  }

  @override
  String toString() {
    return """
   Country : ${this.country}
   County : ${this.county}
   Event : ${this.event}
   Tempature : ${this.tempature}
   WindSpeed : ${this.windSpeed}
   WindDirectionAngle : ${this.windDirectionAngle}
   Date : ${this.dateTime}
   """;
  }

  Map<String, dynamic> toJson() {
    //Class'ımızı jsona çevirmek için kullanacağımız fonksiyon.
    return {
      "country": this.country,
      "event": this.event,
      "tempature": this.tempature,
      "windSpeed": this.windSpeed,
      "windDirectionAngle": this.windDirectionAngle,
      "dateTime": DateFormat('yyyy-MM-dd HH:mm:ss').format(this.dateTime)
    };
  }

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      country: json["country"],
      county: json["county"],
      event: json["event"],
      tempature: json["tempature"],
      windSpeed: json["windSpeed"],
      windDirectionAngle: json["windDirectionAngle"],
      dateTime: DateTime.parse(json["dateTime"]),
    );
  }
}

//Saatlik  hava durumu verisini tutan class.
final class WeatherHourlyData extends WeatherData {
  late final double maximunWindSpeed;

  WeatherHourlyData(
      {String? country,
      String? county,
      double? maximunWindSpeed,
      String? event,
      double? tempature,
      double? windSpeed,
      int? windDirectionAngle,
      DateTime? dateTime})
      : super(
            country: country,
            county: county,
            event: event,
            tempature: tempature,
            windSpeed: windSpeed,
            windDirectionAngle: windDirectionAngle,
            dateTime: dateTime) {
    this.maximunWindSpeed = maximunWindSpeed ?? INVALID_MAGIC_PARAMETER;
  }

  @override
  String toString() {
    return super.toString() + "MaximunWindSpeed : ${this.maximunWindSpeed}";
  }

  factory WeatherHourlyData.fromJson(Map<String, dynamic> json) {
    return WeatherHourlyData(
        country: json["country"],
        county: json["county"],
        maximunWindSpeed: json["maximunWindSpeed"],
        event: json["event"],
        tempature: json["tempature"],
        windSpeed: json["windSpeed"],
        windDirectionAngle: json["windDirectionAngle"],
        dateTime: DateTime.parse(json["dateTime"]));
  }

  Map<String, dynamic> toJson() {
    return {
      "country": this.country,
      "event": this.event,
      "tempature": this.tempature,
      "windSpeed": this.windSpeed,
      "windDirectionAngle": this.windDirectionAngle,
      "dateTime": DateFormat('yyyy-MM-dd HH:mm:ss').format(this.dateTime),
      "maximunWindSpeed": this.maximunWindSpeed
    };
  }
}

///Günlük hava durumu verisini tutan class.
final class WeatherDailyData extends WeatherData {
  ///Minimun ve Maksimun sıcaklık gün içi.
  late final int minTempature, maxTempature;

  WeatherDailyData(
      {String? country,
      String? county,
      String? event,
      double? tempature,
      double? windSpeed,
      int? windDirectionAngle,
      int? maxTempature,
      int? minTempature,
      DateTime? dateTime})
      : super(
            country: country,
            county: county,
            event: event,
            tempature: tempature,
            windSpeed: windSpeed,
            windDirectionAngle: windDirectionAngle,
            dateTime: dateTime) {
    this.maxTempature = maxTempature ?? INVALID_MAGIC_PARAMETER.toInt();
    this.minTempature = minTempature ?? INVALID_MAGIC_PARAMETER.toInt();
  }

  @override
  String toString() {
    return super.toString() +
        "MinTempature : ${this.minTempature}\n MaxTempature : ${this.maxTempature}";
  }

  factory WeatherDailyData.fromJson(Map<String, dynamic> json) {
    return WeatherDailyData(
        country: json["country"],
        county: json["county"],
        event: json["event"],
        tempature: json["tempature"],
        windSpeed: json["windSpeed"],
        windDirectionAngle: json["windDirectionAngle"],
        dateTime: DateTime.parse(json["dateTime"]),
        minTempature: json["minTempature"],
        maxTempature: json["maxTempature"]);
  }

  Map<String, dynamic> toJson() {
    return {
      "country": this.country,
      "event": this.event,
      "tempature": this.tempature,
      "windSpeed": this.windSpeed,
      "windDirectionAngle": this.windDirectionAngle,
      "dateTime": DateFormat('yyyy-MM-dd HH:mm:ss').format(this.dateTime),
      "maxTempature": this.maxTempature,
      "minTempature": this.minTempature
    };
  }
}

/*Bu class'ın constructor'unu çağırmak için önce "initaliaze_API" çağırmanız lazım ve bu işlemlerin hepsi AllCountryCounty'dan veri alıyor.
*/
final class CountryData {
  late final String name;
  late final List<String> counties;
  late final int licensePlate;
  late final double longitude;
  late final double latitude;

  Future<bool> CompareToCounty(String other) async {
    var newStr = turkishToEnglish(other.toLowerCase());

    for (var i in this.counties) {
      if (newStr == turkishToEnglish(i.toLowerCase())) return true;
    }
    return false;
  }

  Future<bool> CompareToACountryName(String other) async {
    return turkishToEnglish(name.toLowerCase()) ==
        turkishToEnglish(other.toLowerCase());
  }

  CountryData.fromJson(obj) {
    this.name = obj["ilAdı"];
    this.licensePlate = 0x00; //burayı ayarla
    this.counties = <String>[];
    this.longitude = obj["boylam"];
    this.latitude = obj["enlem"];
    for (var k in obj["ilçeler"]) this.counties.add(k);
  }

  Map<String, dynamic> toJson() {
    return {
      "ilAdı": this.name,
      "licensePlate": this.licensePlate,
      "ilçeler": this.counties,
      "boylam": this.longitude,
      "enlem": this.latitude
    };
  }

  @override
  String toString() {
    return """ 
    Şehir : ${name}
    Plaka : ${licensePlate}
    İlçeler : ${counties}
    """;
  }
}

//Şimdi artık herhangi bir il veya ilçenin direkt olarak tüm hava durumu bilgilerini tutabilmemiz için var olan class'ımız karşınızda CountryWithWeatherData
final class CountryWithWeatherData {
  late String? countyName; //Tam şehir adını verir il ve ilçe farketmez.
  late CountryData? countryData;
  late WeatherData? latestSituation;
  late List<WeatherDailyData>? daily;
  late List<WeatherHourlyData>? hourly;

  CountryWithWeatherData(
      {this.countryData,
      this.latestSituation,
      this.daily,
      this.hourly,
      this.countyName}) {}

  //Verilerimizi MGM'den çekip güzelce yerleştiriyor member'larımıza.

  Future<WeatherAppError> fromRequest(String il, String ilce) async {
    //CountryName illa il adı olmak zorunda değil , ilçede olabilir.

    var obj = await CheckCountryName(il, ilce);
    if (obj == null)
      return WeatherAppError(
          errorCode: WeatherAppErrorCode.InvalidArgument,
          what: "Invalid country name  => countyName : ${countyName}");

    var error1 = await WeatherAppContext.LoadWeatherDataFromMGM(il, ilce,
        weatherType: MGMWeatherType.MGM_LatestSituation); //Son durum verisi

    if (error1.errorCode != WeatherAppErrorCode.Success) return error1;
    this.latestSituation = error1.returnValue;

    var error2 = await WeatherAppContext.LoadWeatherDataFromMGM(il, ilce,
        weatherType: MGMWeatherType.MGM_Daily); //Günlük veriler.

    if (error2.errorCode == WeatherAppErrorCode.Success)
      this.daily = error2.returnValue;
    else
      this.daily = null;

    var error3 = await WeatherAppContext.LoadWeatherDataFromMGM(il, ilce,
        weatherType: MGMWeatherType.MGM_Hourly); //Saatlik veriler.

    if (error3.errorCode == WeatherAppErrorCode.Success)
      this.hourly = error3.returnValue;
    else
      this.hourly = null;

    this.countyName = ilce;
    this.countryData = obj;
    return WeatherAppError();
  }

  factory CountryWithWeatherData.fromJson(json) {
    return CountryWithWeatherData(
        countryData: CountryData.fromJson(json["countryData"]),
        countyName: json["countyName"],
        latestSituation: WeatherData.fromJson(json["latestSituation"]),
        daily: json["daily"] != null
            ? List<WeatherDailyData>.generate(json["daily"].length, (index) {
                return WeatherDailyData.fromJson(json["daily"][index]);
              })
            : [],
        hourly: json["hourly"] != null
            ? List<WeatherHourlyData>.generate(json["hourly"].length, (index) {
                return WeatherHourlyData.fromJson(json["hourly"][index]);
              })
            : []);
  }

  Map<String, dynamic> toJson() {
    return {
      "countyName": this.countyName,
      "countryData": this.countryData,
      "latestSituation": this.latestSituation,
      "daily": this.daily,
      "hourly": this.hourly
    };
  }

  @override
  String toString() {
    return """
    Şehir Adı : ${countryData?.name} 
    Son Durum : ${latestSituation}
    Saatlik : ${hourly}
    Günlük : ${daily}""";
  }
}

//Mgm ile yapılacak olan işlemler için ilk fonksiyon.
Future<WeatherAppError> initaliaze_API() async {
  APPContext = WeatherAppContext();
  Directory? appDocDirectory = await getDownloadsDirectory();
  var connection = await InternetConnectionChecker().hasConnection;

  if (connection) {
    try {
      //MGM'den request yapıyoruz tüm il'lerin özel bilgilerini almak için.
      var allCountryCounty = await http.get(
          Uri.parse(MGMUrl.MGM_AllCountryCounty_URL.url),
          headers: CommonHeadersForHtppRequest);

      if (allCountryCounty.statusCode != 200)
        return WeatherAppError(errorCode: WeatherAppErrorCode.RequestError);

      AllCountryCountyMGM = jsonDecode(ConvertUtf8(allCountryCounty
          .bodyBytes)); //MGM'den illerin hepsini json olarak yükledik.

/*
    List<Map<String,dynamic>> mpLst = [];
    for (var i in AllCountryCountyMGM){


      while(true){
      try {
        var ilcelerJson = await http.get(
            Uri.parse(MGMUrl.MGM_CountryCounties_URL.url +FirstCharBigAnotherSmall(turkishToEnglish(i["il"]) )),
            headers: CommonHeadersForHtppRequest);
        List<String> ilcelerList = [];
        print(FirstCharBigAnotherSmall(turkishToEnglish(i["il"]) ));
        if (ilcelerJson.statusCode == 200) {
          var json = jsonDecode(ConvertUtf8(ilcelerJson.bodyBytes));

         for (var k in json)
          ilcelerList.add(k["ilce"]);

         mpLst.add({"ilAdı" : i["il"]  , "enlem" : i["enlem"] , "boylam" : i["boylam"] , "ilçeler" : ilcelerList ,  });
        await Future.delayed(Duration(milliseconds: 500));
        break;


        }

      } catch(e){
        print("break me : " + e.toString());
      }}


    }

      File dosya = File(appDocDirectory!.path + "/ilceler.json");
      dosya.createSync(recursive: true);
      RandomAccessFile dosyaYaz = dosya.openSync(mode: FileMode.write);

      // Metni dosyaya yazın
      dosyaYaz.writeStringSync(jsonEncode(mpLst));

      // Dosyayı kapatın
      dosyaYaz.closeSync();
*/
    } catch (e) {
      return WeatherAppError(
          errorCode: WeatherAppErrorCode.Exception, what: e.toString());
    }
  }

  var AllCountryCountyJSON = jsonDecode(ListUInt8ToString(
      (await GetBufferFromFile("assets/files/il-ilce.json"))
          .returnValue)); //Tüm il ve ilçe ne varsa hepsini json olarak yükledik.
  for (var i in AllCountryCountyJSON)
    AllCountryCounty.add(CountryData.fromJson(i));

  return await APPContext.Load();
}

/*
* ililcesi/il=? -> tüm şehirlerin ilçesini ile göre döndürür.
* {
* aciklama
alternatifHadiseIstNo
boylam
enlem
gunlukTahminIstNo
il
ilPlaka
ilce
merkezId
modelId
oncelik
saatlikTahminIstNo
sondurumIstNo
yukseklik
* }

*sondurumlar?merkezid=
* aktuelBasinc
denizSicaklik
denizVeriZamani
denizeIndirgenmisBasinc
gorus
hadiseKodu
istNo
kapalilik
karYukseklik
nem
rasatMetar
rasatSinoptik
rasatTaf
ruzgarHiz
ruzgarYon
sicaklik
veriZamani
yagis00Now
yagis1Saat
yagis6Saat
yagis10Dk
yagis12Saat
yagis24Saat
*
*gunluk?istno=
*  enDusukGun1
enDusukGun2
enDusukGun3
enDusukGun4
enDusukGun5
enDusukNemGun1
enDusukNemGun2
enDusukNemGun3
enDusukNemGun4
enDusukNemGun5
enYuksekGun1
enYuksekGun2
enYuksekGun3
enYuksekGun4
enYuksekGun5
enYuksekNemGun1
enYuksekNemGun2
enYuksekNemGun3
enYuksekNemGun4
enYuksekNemGun5
hadiseGun1
hadiseGun2
hadiseGun3
hadiseGun4
hadiseGun5
istNo
ruzgarHizGun1
ruzgarHizGun2
ruzgarHizGun3
ruzgarHizGun4
ruzgarHizGun5
ruzgarYonGun1
ruzgarYonGun2
ruzgarYonGun3
ruzgarYonGun4
ruzgarYonGun5
tarihGun1
tarihGun2
tarihGun3
tarihGun4
tarihGun5
*
*
* saatlik?istno
*
baslangicZamani
istNo
merkez
tahmin : [
{
hadise
hissedilenSicaklik
maksimumRuzgarHizi
nem
ruzgarHizi
ruzgarYonu
sicaklik
tarih
*
*}]
* */
