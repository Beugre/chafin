library dataconnect_generated;
import 'package:firebase_data_connect/firebase_data_connect.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';

part 'create_public_movie_list.dart';

part 'list_public_movie_lists.dart';

part 'add_movie_to_list.dart';

part 'list_movies_in_list.dart';







class ExampleConnector {
  
  
  CreatePublicMovieListVariablesBuilder createPublicMovieList ({required String name, }) {
    return CreatePublicMovieListVariablesBuilder(dataConnect, name: name,);
  }
  
  
  ListPublicMovieListsVariablesBuilder listPublicMovieLists () {
    return ListPublicMovieListsVariablesBuilder(dataConnect, );
  }
  
  
  AddMovieToListVariablesBuilder addMovieToList ({required String movieListId, required String movieId, required int position, }) {
    return AddMovieToListVariablesBuilder(dataConnect, movieListId: movieListId,movieId: movieId,position: position,);
  }
  
  
  ListMoviesInListVariablesBuilder listMoviesInList ({required String movieListId, }) {
    return ListMoviesInListVariablesBuilder(dataConnect, movieListId: movieListId,);
  }
  

  static ConnectorConfig connectorConfig = ConnectorConfig(
    'us-west1',
    'example',
    'chafin',
  );

  ExampleConnector({required this.dataConnect});
  static ExampleConnector get instance {
    return ExampleConnector(
        dataConnect: FirebaseDataConnect.instanceFor(
            connectorConfig: connectorConfig,
            sdkType: CallerSDKType.generated));
  }

  FirebaseDataConnect dataConnect;
}

