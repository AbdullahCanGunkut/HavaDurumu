import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:geolocator/geolocator.dart';

import 'package:flutter/services.dart' show ByteData, rootBundle;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'weatherAPI.dart';
import 'package:pair/pair.dart';

/*
* UI ve diğer kodlar tarafından sık kullanılan bir kütüphane
*
* */

const Map<String, String> DayOfWeekShortened = {
  'Pazartesi': 'Pzt',
  'Salı': 'Sal',
  'Çarşamba': 'Çrş',
  'Perşembe': 'Prş',
  'Cuma': 'Cum',
  'Cumartesi': 'Cmts',
  'Pazar': 'Pzr'
};

const Map<String, String> EventCodeMap = {
  "A": "Açık (Güneşli)",
  "F": "Fırtına",
  "K": "Kapalı (Bulutlu)",
  "Y": "Yüksek Sıcaklık",
  "CB": "Çok Bulutlu",
  "AB": "Az Bulutlu",
  "TF": "Toz Fırtınası",
  "HY": "Hafif Yağmur",
  "KY": "Kar Yağışı",
  "KF": "Kuvvetli Fırtına",
  "KR": "Kuvvetli Rüzgar",
  "DY": "Don Yağışı",
  "KS": "Kuvvetli Sağanak Yağış",
  "R": "Rüzgarlı",
  "KVF": "Kuvvetli Fırtına",
  "SCK": "Sağanaklı Çok Bulutlu",
  "SGK": "Sağanaklı Güneşli",
  "NUL": "Normal Yağışlı",
  "DMN": "Don",
  "PRN": "Parçalı Rüzgarlı",
  "CON": "Çok Güneşli",
  "GKR": "Gökgürültülü Kuvvetli Rüzgar",
  "KKR": "Karlı Kuvvetli Rüzgar",
  "SIS": "Sisli",
  "PUS": "Puslu",
  "KGY": "Kuvvetli Gökgürültülü Yağışlı",
  "HKY": "Hafif Kar Yağışlı",
  "KKY": "Kuvvetli Kar Yağışlı",
  "HHY": "Hafif Hava Yağışlı",
  "YKY": "Yoğun Kar Yağışlı",
  "GSY": "Güneşli",
  "HSY": "Hafif Sağanaklı Yağışlı",
  "MSY": "Mavi Saatlerde Yağışlı",
  "KSY": "Kar Yağışlı"
};

String turkishToEnglish(String input) {
  //Türkçe karakterleri ingilizceye çevirmemiz lazım request ederken.
  Map<String, String> charMap = {
    'ı': 'i',
    'ğ': 'g',
    'ü': 'u',
    'ş': 's',
    'ö': 'o',
    'ç': 'c',
    'İ': 'I',
    'Ğ': 'G',
    'Ü': 'U',
    'Ş': 'S',
    'Ö': 'O',
    'Ç': 'C'
  };

  String result = '';

  for (int i = 0; i < input.length; i++) {
    String char = input[i];
    String convertedChar = charMap[char] ??
        char; // Eğer karakter dönüşümü yoksa aynı karakteri kullan
    result += convertedChar;
  }

  return result;
}

///İlk harfi büyük diğer harfleri küçük yapar.
String FirstCharBigAnotherSmall(String str) =>
    str.substring(0, 1).toUpperCase() + str.substring(1).toLowerCase();

///bytes'ları batının diline odaklı (türkçede dahil olmak üzere) 8 byte'lık okunabilir yazıya dönüştürür.
String ConvertUtf8(List<int> bytes) => utf8.decode(bytes);

///Int listemizi utf8 çevirme
String ListIntToString(List<int> list) => ConvertUtf8(list);

///Uint listemizi utf8 çevirme
String ListUInt8ToString(Uint8List list) => ConvertUtf8(list.toList());

///Belirtilen yoldan eğer path geçerli ise raw veriyi alma.
Future<WeatherAppError> GetBufferFromFile(String path,
    {WeatherAppPathType? pathType, bool? readAsChar}) async {
  try {
    //Dosyadan veri yükleme
    pathType ??= WeatherAppPathType.Assets; //Varsayılan olarak assets ayarlar
    readAsChar ??=
        false; //Eğer dosyayı metinsel olark okumak istiyorsak kullanacağız.

    Uint8List data = Uint8List(0); // Dosyayı yükle
    String new_path = path; //Switch bloğu içinde 'pathType' göre şekillenir.
    switch (pathType) {
      //Dosyamızı hangi konumlardan almak istiyorsak
      case WeatherAppPathType.Assets:
        return WeatherAppError(
            returnValue: (await rootBundle.load(path)).buffer.asUint8List());

      case WeatherAppPathType.Relative:
        new_path = (await getApplicationDocumentsDirectory()).path + path;
        break;

      default:
        break;
    }

    data = File(new_path).readAsBytesSync();
    return data.length > 0
        ? WeatherAppError(returnValue: data)
        : WeatherAppError(
            errorCode: WeatherAppErrorCode.InvalidArgument,
            what: "File hasn't loaded from path => Path : ${path}");
  } catch (e) {
    return WeatherAppError(
        errorCode: WeatherAppErrorCode.Exception, what: e.toString());
  }
}

///Resim yükleme internet veya belirtilen konum tipine göre düzeltebilirsiniz.
///width argümanı SvgPicture'ların width'ini belirlemek için kullanılır.
///imageType yüklenecek olan resim türünü belirtir.
///
FutureOr<WeatherAppError> loadImageFromPath(String path,
    {Map<String, dynamic>? sharedImages,
    WeatherAppPathType? pathType,
    double? width,
    WeatherAppImageType? imageType}) async {
  pathType ??= WeatherAppPathType.Url;
  imageType ??= WeatherAppImageType.Svg;

  dynamic imgObject = null;
  width ??= 32;
  var dir = (await getApplicationDocumentsDirectory()).path + "/temp/";

  ///Resimleri cacheten alma işlemini yapan kodlar.
  if (sharedImages != null && sharedImages.containsKey(path)) {
    ///dosyaya eğer yüklendi ise onu direkt olaraktan alalım ve bu performans açısından oldukça önemlidir , bilgisayar yeniden dosya yükleme yapmaz{

/*
    var new_path = path + width.toString();

    if (imageType == WeatherAppImageType.Svg) {///Burayı cache'tan almak için yapacağız.

      if (sharedImages.containsKey(new_path)) {
        return WeatherAppError(returnValue: sharedImages[new_path]);
      }else {

        var file = await GetBufferFromFile(dir + path
            .split(RegExp(r"\/"))
            .last, pathType: pathType);
        if (file.errorCode != WeatherAppErrorCode.Success) return file;
        imgObject = (SvgPicture.memory(file.returnValue, width: width! , height:width! , fit : BoxFit.fill));
        sharedImages[new_path] = imgObject;

        return WeatherAppError(returnValue: sharedImages[new_path]);
      }

      }*/

    return WeatherAppError(returnValue: sharedImages[path]);
  }

  try {
    if (pathType != WeatherAppPathType.Url) {
      //Eğer alınacak resimler internetten değilse dosyaya göre işlem yapacağız.
      var file = await GetBufferFromFile(path, pathType: pathType);
      if (file.errorCode != WeatherAppErrorCode.Success) return file;
      if (imageType == WeatherAppImageType.Image) {
        imgObject = (Image.memory(file.returnValue));
      } else if (imageType == WeatherAppImageType.Svg) {
        imgObject = (SvgPicture.memory(file.returnValue, width: width! , height:width! , fit : BoxFit.fill));
      } else
        return WeatherAppError(
            errorCode: WeatherAppErrorCode.TypeError,
            what:
                "ImageType isn't any sub class of these : Image , SvgPicture");
    } else {
      //Alıncak resimlerin internet üzerinde alınması
      if (imageType == WeatherAppImageType.Image) {
        imgObject = Image.network(path);
      } else if (imageType == WeatherAppImageType.Svg) {

        imgObject = SvgPicture.network(path, width: width! , height:width! , fit : BoxFit.fill);
        sharedImages?[path] = imgObject;
      } else
        return WeatherAppError(
            errorCode: WeatherAppErrorCode.TypeError,
            what:
                "ImageType isn't any sub class of these : Image , SvgPicture");
    }
  } catch (e) {
    return WeatherAppError(
        errorCode: WeatherAppErrorCode.Exception, what: e.toString());
  }
  sharedImages?[path] = imgObject;

  return WeatherAppError(
      returnValue: imgObject); // Byte dizisinden görüntüyü yükle
}

///AllCountryMGM json değişkeninden il adına göre map verisini alma.
Future<WeatherAppError> GetCountryFromAllCountryMGM(String il) async {
  try {
    for (var obj in AllCountryCountyMGM)
      if (obj["il"] == il) return WeatherAppError(returnValue: obj);
  } catch (e) {
    return WeatherAppError(
        errorCode: WeatherAppErrorCode.Exception, what: e.toString());
  }
  return WeatherAppError(
      errorCode: WeatherAppErrorCode.InvalidArgument,
      what: "Argument is not valid : \"il\" : ${il}");
}

Future<WeatherAppError> GetCountryCounties(String il, {String? ilce}) async {
  try {
    var request = await http.get(
        Uri.parse(MGMUrl.MGM_CountryCounty_URL.url + il),
        headers: CommonHeadersForHtppRequest);

    if (request.statusCode == 200) {
      List<dynamic> jsonData = jsonDecode(ConvertUtf8(request.bodyBytes));

      if (ilce != null) {
        for (var obj in jsonData) {
          if (obj["ilce"] != null && obj["ilce"] == ilce)
            return WeatherAppError(returnValue: obj);
        }

        // return  WeatherAppError(returnValue: retValue); WeatherAppError(errorCode: WeatherAppErrorCode.AnyError , what: "Argument is not valid => \"ilçe\" : ${ilce} !");
        return WeatherAppError(
            errorCode: WeatherAppErrorCode.AnyError,
            what: "Request json (null)(ilçe) !");
      } else {
        if (json != null)
          return WeatherAppError(returnValue: json);
        else
          return WeatherAppError(
              errorCode: WeatherAppErrorCode.AnyError,
              what: "Request json (null) !");
      }
    }
    return WeatherAppError(
        errorCode: WeatherAppErrorCode.InvalidArgument,
        what: "Argument is not valid => \"il\" : ${il} !");
  } catch (e) {
    return WeatherAppError(
        errorCode: WeatherAppErrorCode.Exception, what: e.toString());
  }
}

/// Determine the current position of the device.
///
/// When the location services are not enabled or permissions
/// are denied the `Future` will return an error.
Future<WeatherAppError> GetCurrentLocationName() async {
  /// Konum bilgilerini almak için izin iste (gerekiyorsa)
  ///

  try {
    var permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied) {
      print('Konum izni reddedildi !');
      return WeatherAppError(
          errorCode: WeatherAppErrorCode.AnyError,
          what: "Konum izni reddedildi ! ",
          returnValue: "");
    }

    // Konum bilgilerini al
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);

    // Enlem ve boylam değerlerini al
    double latitude = position.latitude;
    double longitude = position.longitude;

    // Konum bilgisini kullanarak adresi al
    var address = await GetAddressFromCoordinates(latitude, longitude);
    return WeatherAppError(returnValue: address.returnValue);
  }catch(e){
    return WeatherAppError(errorCode: WeatherAppErrorCode.Exception, returnValue: e.toString());
  }

}

Future<WeatherAppError> GetAddressFromCoordinates(
    double latitude, double longitude) async {
  print("""lat: $latitude,
    lon: $longitude""");

  try {
    var httpClient = HttpClient();
    var uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'format': 'json',
      'lat': '$latitude',
      'lon': '$longitude',
      'zoom': '18',
      'addressdetails': '1'
    });

    var request = await httpClient.getUrl(uri);
    var response = await request.close();

    if (response.statusCode == 200) {
      var responseBody = await response.transform(utf8.decoder).join();
      var jsonResponse = json.decode(responseBody);

      print("response : " + jsonResponse.toString());
      return WeatherAppError(
          returnValue: Pair(jsonResponse['address']["province"].toString(),
              jsonResponse['address']["town"].toString()));
    } else {
      return WeatherAppError(
          returnValue: "",
          errorCode: WeatherAppErrorCode.AnyError,
          what: "Location hasn't found !");
    }
  } catch (e) {
    return WeatherAppError(
        errorCode: WeatherAppErrorCode.Exception, what: e.toString());
  }
}

Future<List<String>> getAllFileNames(String directoryPath) async {
  List<String> allFileNames = [];

  // Directory nesnesi oluştur
  Directory directory = Directory(directoryPath);

  // Dizin var mı kontrol et
  if (await directory.exists()) {
    // Dizin içindeki dosyaları listele
    List<FileSystemEntity> files = directory.listSync();
    for (FileSystemEntity file in files) {
      // Dosya mı kontrol et
      if (file is File) {
        // Dosya ismini listeye ekle
        allFileNames.add(file.path.split('/').last); // Sadece dosya adını al
      }
    }
  } else {
    print('Belirtilen dizin bulunamadı: $directoryPath');
  }

  return allFileNames;
}

///Eğer CountryName eşleşirse CountryData verisini alır AllCountryCounty'dan ve Country data ile Pair(il , ilce) döndürür.
///Not : CountryName il veya ilçe olabilir.
Future<CountryData?> CheckCountryName(String il, String ilce) async {
  for (var i in AllCountryCounty) {
    if (await i.CompareToACountryName(il) && await i.CompareToCounty(ilce))
      return i;
  }
  return null;
}
