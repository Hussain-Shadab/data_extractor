
import 'dart:convert';

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
class ImageTextExtractor extends StatefulWidget {
  const ImageTextExtractor({super.key});

  @override
  State<ImageTextExtractor> createState() => _ImageTextExtractorState();
}

class _ImageTextExtractorState extends State<ImageTextExtractor> {
  // to hold pickimage
  File? _image;
  // to store extracted text
  String extractedText = '';
  List<List<String>> extractedTables=[];
  bool isLoading = false;

  final String endpoint = 'https://form-rg.cognitiveservices.azure.com/';
  final String apiKey = '72siqfZpTFMoyDZk5ykvAyVHr3Xc29BUQCR7Xl50N6TCiZfwGf63JQQJ99BDAC3pKaRXJ3w3AAALACOGR1hH';

  // Now PickImage from Gallery
  Future<void> pickImage() async{
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if(picked != null){
      setState(() {
        _image = File(picked.path);
        extractedText = '';
        extractedTables = [];
      });
      analyzeImage(_image!);
    }
  }
  Future<void> analyzeImage(File imageFile) async {
    setState(() {
      isLoading = true;
    });

    final url = Uri.parse(
      '$endpoint/formrecognizer/documentModels/prebuilt-layout:analyze?api-version=2023-07-31',
    );

    // Read image bytes
    final imageBytes = await imageFile.readAsBytes();

    // Send request using http.post (correct method for Form Recognizer)
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/octet-stream',
        'Ocp-Apim-Subscription-Key': apiKey,
      },
      body: imageBytes,
    );

    if (response.statusCode == 202) {
      final operationLocation = response.headers['operation-location'];

      if (operationLocation != null) {
        await Future.delayed(Duration(seconds: 5));

        final result = await http.get(Uri.parse(operationLocation), headers: {
          'Ocp-Apim-Subscription-Key': apiKey,
        });

        final jsonData = json.decode(result.body);

        // ✅ Extract plain text
        final extractedText = jsonData['analyzeResult']['content'] ?? 'No text found';

        // ✅ Extract table if available
        List<List<String>> extractedTables = [];
        final tablesResult = jsonData['analyzeResult']['tables'];

        if (tablesResult != null) {
          for (var table in tablesResult) {
            final int rowCount = table['rowCount'];
            final int columnCount = table['columnCount'];

            List<List<String>> rows = List.generate(rowCount, (_) => List.generate(columnCount, (_) => ''));

            for (var cell in table['cells']) {
              int row = cell['rowIndex'];
              int col = cell['columnIndex'];
              String content = cell['content'] ?? '';
              rows[row][col] = content;
            }

            extractedTables = rows;
          }
        }

        setState(() {
          this.extractedText = extractedText;
          this.extractedTables = extractedTables;
          isLoading = false;
        });
      }
    } else {
      setState(() => isLoading = false);
      print('❌ Failed to analyze image');
      print('Status code: ${response.statusCode}');
      // print('Response: ${await response.stream.bytesToString()}');
    }
  }

  Widget buildTableView() {
    if (extractedTables.isEmpty) return SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Extracted Tables:', style: TextStyle(fontWeight: FontWeight.bold,color: Colors.black),),
        SizedBox(height: 10,),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,

          child: Table(
            defaultColumnWidth: FixedColumnWidth(100),
            border: TableBorder.all(),
            children: extractedTables.map((row){
              return TableRow(
                children: row.map((cell){
                  return Padding(padding: const EdgeInsets.all(8),
                  child: Text(cell,style: TextStyle(color: Colors.black,fontSize: 20),),
                  );
                }).toList(),
              );
            }).toList(),
          ),
        )
      ],
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Data Extractor'),
      ),
      body: Padding(
        padding: EdgeInsets.all(15),
        child: SingleChildScrollView(

          child: Column(
            children: [
              ElevatedButton(onPressed: pickImage,
                  child: Text('Pick Image',style: TextStyle(
                    fontSize: 30,

                  ),)),
              SizedBox(height: 10,),
              if(_image != null) Image.file(_image! , height: 160,width: 150,),
              SizedBox(height: 20,),
              if(isLoading) CircularProgressIndicator(),

              if(extractedText.isNotEmpty) ...[
                Text('📜 ExtractedText: ',style:  TextStyle(fontSize: 10,color: Colors.black),),
                SizedBox(height: 10,),
                Text(extractedText)
              ],
              SizedBox(height: 20,),
              if(extractedTables.isNotEmpty) buildTableView(),
            ],
          ),
        ),
      ),
    );
  }
}
