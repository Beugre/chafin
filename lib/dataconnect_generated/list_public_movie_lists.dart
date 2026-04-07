part of 'example.dart';

class ListPublicMovieListsVariablesBuilder {
  
  final FirebaseDataConnect _dataConnect;
  ListPublicMovieListsVariablesBuilder(this._dataConnect, );
  Deserializer<ListPublicMovieListsData> dataDeserializer = (dynamic json)  => ListPublicMovieListsData.fromJson(jsonDecode(json));
  
  Future<QueryResult<ListPublicMovieListsData, void>> execute() {
    return ref().execute();
  }

  QueryRef<ListPublicMovieListsData, void> ref() {
    
    return _dataConnect.query("ListPublicMovieLists", dataDeserializer, emptySerializer, null);
  }
}

@immutable
class ListPublicMovieListsMovieLists {
  final String id;
  final String name;
  final String? description;
  ListPublicMovieListsMovieLists.fromJson(dynamic json):
  
  id = nativeFromJson<String>(json['id']),
  name = nativeFromJson<String>(json['name']),
  description = json['description'] == null ? null : nativeFromJson<String>(json['description']);
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListPublicMovieListsMovieLists otherTyped = other as ListPublicMovieListsMovieLists;
    return id == otherTyped.id && 
    name == otherTyped.name && 
    description == otherTyped.description;
    
  }
  @override
  int get hashCode => Object.hash(id.hashCode, name.hashCode, description.hashCode);
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['id'] = nativeToJson<String>(id);
    json['name'] = nativeToJson<String>(name);
    if (description != null) {
      json['description'] = nativeToJson<String?>(description);
    }
    return json;
  }

  ListPublicMovieListsMovieLists({
    required this.id,
    required this.name,
    this.description,
  });
}

@immutable
class ListPublicMovieListsData {
  final List<ListPublicMovieListsMovieLists> movieLists;
  ListPublicMovieListsData.fromJson(dynamic json):
  
  movieLists = (json['movieLists'] as List<dynamic>)
        .map((e) => ListPublicMovieListsMovieLists.fromJson(e))
        .toList();
  @override
  bool operator ==(Object other) {
    if(identical(this, other)) {
      return true;
    }
    if(other.runtimeType != runtimeType) {
      return false;
    }

    final ListPublicMovieListsData otherTyped = other as ListPublicMovieListsData;
    return movieLists == otherTyped.movieLists;
    
  }
  @override
  int get hashCode => movieLists.hashCode;
  

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {};
    json['movieLists'] = movieLists.map((e) => e.toJson()).toList();
    return json;
  }

  ListPublicMovieListsData({
    required this.movieLists,
  });
}

