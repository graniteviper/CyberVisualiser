// -------------------------------------------- LG SERVICE --------------------------------------------
// File dedicated to manage everything that has to do with the connection to the Liquid Galaxy

// ---------------------- Import packages ----------------------
import 'dart:async'; // Imports the Dart asynchronous tools
import 'dart:io'; // Used for handling socket exceptions and network errors
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // Imports the foundation librray used to manage ChangeNotification
import 'package:dartssh2/dartssh2.dart'; // SSH package used to connect to and send commands to the Liquid Galaxy
// IMPORTANT!! Add this also in pubspec.yaml

import 'package:shared_preferences/shared_preferences.dart'; // Imports shared_preferences to storing small amounts of persistent data
// For example, app settings

import 'package:path_provider/path_provider.dart'; // Imports path_provider to find locations on the app filesystem
import '../models/screen_overlay_kml_model.dart';

// ---------------------- LG model ----------------------
// Model used for storing Liquid Galaxy connection parameters
class LgConnectionModel {
  String username;
  // The "username" variable is used to store the username for SSH login

  String ip;
  // The "ip" variable is used to store the IP address of the Liquid Galaxy host

  int port;
  // The "port" variable is used to store the port number of the SSH connection

  String password;
  // The "password" variable is used to store the password for SSH authentication

  int screens;
  // The "screens" variable is used to store the number of screens in the Liquid Galaxy rig

  // ---- Keys used to store values from shared preferences ----
  static const String _keyUsername = 'lg_username';
  // The _keyUsername key will be used to store and retrieve the username from SharedPreferences
  // It is initialized to the default vale 'lg_username'

  static const String _keyIp = 'lg_ip';
  // The _keyIp key will be used to store and retrieve the ip from SharedPreferences
  // It is initialized to the default vale 'lg_ip'

  static const String _keyPort = 'lg_port';
  // The _keyPort key will be used to store and retrieve the port number from SharedPreferences
  // It is initialized to the default vale 'lg_port'

  static const String _keyPassword = 'lg_password';
  // The _keyPassword key will be used to store and retrieve the password from SharedPreferences
  // It is initialized to the default vale 'lg_password'

  static const String _keyScreens = 'lg_screens';
  // The _keyScreens key will be used to store and retrieve the number o
  //f screens from SharedPreferences
  // It is initialized to the default vale 'lg_screens'

  LgConnectionModel({
    this.username = 'lg',
    // Default username

    this.ip = '',
    // Default IP address

    this.port = 22,
    // Default port number

    this.password = 'lqgalaxy',
    // Default password

    this.screens = 3,
    // Default number of screens
  });

  // -------- updateConnection --------
  // Updates the values of the connection with the new parameters provided if they are not null
  void updateConnection({
    String? username,
    // Defines parameter called "username" of type String?
    // The ? means this parameter is nullable
    // This means that, if not provided, its value will be "null"

    String? ip,
    // Defines parameter called "ip" of type String?
    // The ? means this parameter is nullable
    // This means that, if not provided, its value will be "null"

    int? port,
    // Defines parameter called "port" of type int?
    // The ? means this parameter is nullable
    // This means that, if not provided, its value will be "null"

    String? password,
    // Defines parameter called "password" of type String?
    // The ? means this parameter is nullable
    // This means that, if not provided, its value will be "null"

    int? screens,
    // Defines parameter called "screens" of type int?
    // The ? means this parameter is nullable
    // This means that, if not provided, its value will be "null"
  }) {
    this.username = username ?? this.username;
    // If a new username is provided ("username"), updates the username field with this vale
    // If not, the fallback value (the value after ??) is used, which in this case is the old value (this.username)

    this.ip = ip ?? this.ip;
    // If a new ip is provided ("ip"), updates the ip field with this vale
    // If not, the fallback value (the value after ??) is used, which in this case is the old value (this.ip)

    this.port = port ?? this.port;
    // If a new port number is provided ("port"), updates the port field with this vale
    // If not, the fallback value (the value after ??) is used, which in this case is the old value (this.port)

    this.password = password ?? this.password;
    // If a new password is provided ("password"), updates the password field with this vale
    // If not, the fallback value (the value after ??) is used, which in this case is the old value (this.password)

    this.screens = screens ?? this.screens;
    // If a new number of screens is provided ("screens"), updates the screens field with this vale
    // If not, the fallback value (the value after ??) is used, which in this case is the old value (this.screens)
  }

  // -------- saveToPreferences() method --------
  // Saves the current connection values to the preferences stored in the local storage

  Future<void> saveToPreferences() async {
    // Defines an asynchronous method that does not return any value (void)
    // 'async' allows to use 'await' inside the function
    // It does not return any value because its function is to trigger a side-effect, not to return data

    final prefs = await SharedPreferences.getInstance();
    // SharedPreferences.getInstance() is used to get access to local storage
    // 'await' pauses execution until the file is fully loaded
    // The reference to the preferences storage is saved in the "prefs" variable

    await prefs.setString(_keyUsername, username);
    // Saves the "username" value in local storage under the "_keyUsername" key

    await prefs.setString(_keyIp, ip);
    // Saves the "ip" value in local storage under the "_keyIp" key

    await prefs.setInt(_keyPort, port);
    // Saves the "port" value in local storage under the "_keyPort" key

    await prefs.setString(_keyPassword, password);
    // Saves the "password" value in local storage under the "_keyPassword" key

    await prefs.setInt(_keyScreens, screens);
    // Saves the "screens" value in local storage under the "_keyScreens" key
  }

  // -------- loadFromPreferences() --------
  // Loads connection values from shared preferences and returns a new model instance
  static Future<LgConnectionModel> loadFromPreferences() async {
    // Defines an asynchronous method that does not return any value (void)
    // 'async' allows to use 'await' inside the function

    final prefs = await SharedPreferences.getInstance();
    // SharedPreferences.getInstance() is used to get access to local storage
    // 'await' pauses execution until the file is fully loaded
    // The reference to the preferences storage is saved in the "prefs" variable

    return LgConnectionModel(
      // New model instance

      username: prefs.getString(_keyUsername) ?? 'lg',
      // Loads the username from local storage (prefs.getString(_keyUsername))
      // If there is no username in local storage, the fallback value (the value after ??) is used
      // Which in this case is the default value established earlier ('lg')

      ip: prefs.getString(_keyIp) ?? '',
      // Loads the ip from local storage (prefs.getString(_keyIp))
      // If there is no ip in local storage, the fallback value (the value after ??) is used
      // Which in this case is the default value established earlier ('')

      port: prefs.getInt(_keyPort) ?? 22,
      // Loads the port from local storage (prefs.getString(_keyPort))
      // If there is no port in local storage, the fallback value (the value after ??) is used
      // Which in this case is the default value established earlier (22)

      password: prefs.getString(_keyPassword) ?? 'lqgalaxy',
      // Loads the password from local storage (prefs.getString(_keyPassword))
      // If there is no password in local storage, the fallback value (the value after ??) is used
      // Which in this case is the default value established earlier ('lqgalaxy')

      screens: prefs.getInt(_keyScreens) ?? 5,
      // Loads the screens number from local storage (prefs.getString(_keyScreens))
      // If there is no screens number in local storage, the fallback value (the value after ??) is used
      // Which in this case is the default value established earlier (5)
    );
  }
}


// ---------------------- LgService class ----------------------
// Service to establish and manage the connection to LG
class LgService extends ChangeNotifier {
  // The class LgService extends ChangeNotifierProvider because it allows widgets to listen for changes
  // Makes sure there is only one instance of LgService across the whole app (which is called singleton pattern)
  // Useful to manage a SINGLE connection or state across different parts of the app

  LgService._internal();
  // Private constructor (_), only accessible from within the class
  // Prevents creating multiple instances from outside the class

  static final LgService _singleton = LgService._internal();
  // This line creates and stores the single instance of the LgService class under the name "_singleton"
  // 'static' means it belongs to the class itself, NOT to an object
  // 'final' means it cannot be reassigned after being initialized

  factory LgService() => _singleton;
  // Instead of creating a new object, it returns the existing _instance that was created earlier
  // This enforces the Singleton behavior by always returning the same object

  final LgConnectionModel _lgConnectionModel = LgConnectionModel();
  // Creates a private instance of LgConnectionModel (which holds LG connection settings) under the name "_lgConnectionModel"
  // 'final' means it cannot be reassigned after being initialized

  // -------- SSH client and connection details --------
  SSHClient? _client;
  // The private variable _client will store the active SSH connection
  // ? means it can be null if there is no current connection

  Timer? _orbitTimer;
  // The private variable called _orbitTimer will be used to manage the orbit animation logic
  // Timer is the type of the variable
  // ? means it can be null if there is no current connection

  Timer? _connectionTimer;
  // The private variable called _connectionTimer will be used to check the connection status
  // Timer is the type of the variable
  // ? means it can be null if there is no current connection

  bool _isTrailPlaying = false;
  // Private variable that will be used to track if a trail animation is playing or not
  // It is initialized as false because, by default, there is no animation playing
  // This is because the connection attempt does not start until you press the button to do so
  // The animation will play when the connection is trying to be established

  bool _orbitPlaying = false;
  // Private variable that will be used to check if the orbit animation is active or not
  // It is initialized as false because, by default, there is no animation playing
  // This is because the connection attempt does not start until you press the button to do so
  // The animation will play when the connection is trying to be established

  bool _isConnected = false;
  // Private variable that will be used to check if the Liquid Galaxy is connected or not
  // It is initialized as false because, by default, there is no connection established
  // This is because the connection attempt does not start until you press the button to do so
  // Once the connection attempt finishes, it can be successful (_isConnected = true) or not (_isConnected = false)

  bool _isCheckingConnection = false;
  // Private variable that will be used to
  // It is initialized as false because, by default, there is no connection established
  // This is because the connection attempt does not start until you press the button to do so

  int _currentConnectionAttempts = 0;
  // Private variable that will be used to keep track of the number of reconnect attempts
  // It is initialized to 0 because you have not made any connection attempts yet when you first open the app

  static const int _maxConnectionAttempts = 5;
  // Private variable that establishes the maximum number of reconnect attempts
  // In this case is 5, but you can choose any number you want
  // Although it's better if this number is not too high
  // 'static' means it belongs to the class itself, NOT to an object
  // 'const' means its value will NOT change

  static const Duration _connectionTimeout = Duration(seconds: 10);
  // Private variable that establishes the timeout duration for the connection attempt
  // In this case is 10 seconds, but you can choose any number you want
  // Although it's better if this number is not too high
  // 'static' means it belongs to the class itself, NOT to an object
  // 'const' means its value will NOT change

  LgConnectionModel get connectionModel => _lgConnectionModel;
  // This line returns an object of type LgConnectionModel
  // 'get connectionModel' defines a public getter named 'connectionModel'
  // Getters allow controlled access to private variables to be able to read them
  // '=> _lgConnectionModel' returns the value of the private variable '_lgConnectionModel'

  bool get isConnected => _isConnected;
  // This line returns an object of type bool (true or false)
  // 'get isConnected' defines a public getter named 'isConnected'
  // Getters allow controlled access to private variables to be able to read them
  // '=> _isConnected' returns the value of the private variable '_isConnected'

  // -------- updateConnectionSettings() method --------
  // Used to update the internal Liquid Galaxy connection model with new parameters
  void updateConnectionSettings({
    required String ip,
    // The "ip" variable is used to store the IP address of the Liquid Galaxy host
    // 'required' makes sure this value MUST be provided in order for the method to work

    required int port,
    // The "port" variable is used to store the port number of the SSH connection
    // 'required' makes sure this value MUST be provided in order for the method to work

    required String username,
    // The "username" variable is used to store the username for SSH login
    // 'required' makes sure this value MUST be provided in order for the method to work

    required String password,
    // The "password" variable is used to store the password for SSH authentication
    // 'required' makes sure this value MUST be provided in order for the method to work

    required int screens,
    // The "screens" variable is used to store the number of screens in the Liquid Galaxy rig
    // 'required' makes sure this value MUST be provided in order for the method to work
  }) {
    _lgConnectionModel.updateConnection(
      // Calls the updateConnetion() method from the LG connection model (created at the beginning of this file)

      ip: ip,
      // Updates the value of the 'ip' parameter in the LG connection model with the new value that was provided

      port: port,
      // Updates the value of the 'port' parameter in the LG connection model with the new value that was provided

      username: username,
      // Updates the value of the 'username' parameter in the LG connection model with the new value that was provided

      password: password,
      // Updates the value of the 'password' parameter in the LG connection model with the new value that was provided

      screens: screens,
      // Updates the value of the 'screens' parameter in the LG connection model with the new value that was provided
    );
  }

  // -------- initializeConnection() method --------
  // Used to load the saved connection settings and initiate the connection to the Liquid Galaxy via SSH
  Future<void> initializeConnection() async {
    // Defines an asynchronous method that does not return any value (void)
    // 'async' allows to use 'await' inside the function
    // It does not return any value because its function is to trigger a side-effect, not to return data

    try {
      // try block used to catch any exceptions that may occur

      final savedModel = await LgConnectionModel.loadFromPreferences();
      // LgConnectionModel.loadFromPreferences() is used to load the connection settings from local storage
      // 'await' pauses execution until the file is fully loaded
      // The result is saved in the "savedModel" variable

      updateConnectionSettings(
        // Uses the updateConnectionSettings() method to update the settings values with the ones that were stored

        ip: savedModel.ip,
        // Updates the value of the 'ip' parameter in the LG connection model with the value provided from savedModel

        port: savedModel.port,
        // Updates the value of the 'port' parameter in the LG connection model with the value provided from savedModel

        username: savedModel.username,
        // Updates the value of the 'username' parameter in the LG connection model with the value provided from savedModel

        password: savedModel.password,
        // Updates the value of the 'password' parameter in the LG connection model with the value provided from savedModel

        screens: savedModel.screens,
        // Updates the value of the 'screens' parameter in the LG connection model with the value provided from savedModel
      );
      await connectToLG();
      // connectToLG() is used to attempt a connection with the Liquid Galaxy
      // 'await' pauses execution of the method until the connection attempt is completed
    } catch (e) {
      // Catches any errors thrown during the try block

      debugPrint('Initialization error: $e');
      // Prints the specific error on the debug console
      // NOT VISIBLE TO USERS, only to developers in the debug console
    }
  }

  // -------- connectToLG() method --------
  // Used to attempt a connection to the Liquid Galaxy using the current connection settings
  Future<bool?> connectToLG() async {
    // Defines an asynchronous method that returns a boolean value (true or false)
    // 'async' allows to use 'await' inside the function
    // The ? means this parameter is nullable
    // This means that, if not provided, its value will be "null"

    if (_currentConnectionAttempts >= _maxConnectionAttempts) {
      // Condition that checks if the number of connection attempts has reached the maximum allowed (5 in this case)
      // In case this is true:

      _currentConnectionAttempts = 0;
      // Resets the attempt counter
      // This is beacuse, in this cycle, the maximum number of attempts has been reached
      // So no further attempts will be made in this cycle

      notifyListeners();
      // Notifies any widgets or services listening to this class that a change took place
      // Specifically, that the connection status changed
      // It does it through ChangeNotifier

      return false;
      // Stops the execution and returns false
      // This means that the connection attempt was not made because the maximum number of attempts was reached
    }

    // In case the maximum number of attempts has NOT been reached, the following blocks are executed

    try {
      // try block used to catch any exceptions that may occur

      final socket = await SSHSocket.connect(
        // Attempts to establish a TCP socket connection to the Liquid Galaxy

        _lgConnectionModel.ip,
        // In order to do so, uses the IP provided from the connection model

        _lgConnectionModel.port,
        // And the port provided from the connection model
        // And stores this values in a variable called 'socket'
      ).timeout(_connectionTimeout);
      // .timeout sets a time limit (10 seconds in this case, since we established that _connectionTimeout = Duration(seconds: 10))
      // If it takes longer, it throws a TimeoutException

      _client = SSHClient(
        // Creates an instance from the SSHClient class and stores it in the '_client' variable

        socket,
        // In order to do that, it uses the socket we just created (which has the IP and the port)

        username: _lgConnectionModel.username,
        // Sets the value of the 'username' parameter in the LG connection model with the value provided from the LG connection model

        onPasswordRequest: () => _lgConnectionModel.password,
        // () => _lgConnectionModel.password returns the password stored in the LG connection model
        // Sets this password as the value of the 'onPasswordRequest' parameter
        // This allows SSHClient to ask for the password rather than passing it directly

        keepAliveInterval: const Duration(seconds: 10),
        // const Duration(seconds: 10) creates a Duration object that represents a time interval of 10 seconds
        // This value is provided to the 'keepAliveInterval' parameter
        // This line means that every 10 seconds the SSHClient will send a keep-alive message
        // This is because in many network systems the connection is automatically closed if there is no activity for a while
        // A keep-alive message is a periodic signal sent over a network connection to indicate the connection is still active
      );

      _isConnected = true;
      // If the connection was successful, _isConnected = true

      _currentConnectionAttempts = 0;
      // Since the connection succeeded, the number of connection attempts resets to 0

      notifyListeners();
      // Notifies any widgets or services listening to this class that a change took place
      // Specifically, that the connection status changed
      // It does it through ChangeNotifier

      return true;
      // Returning true indicates that the connection was successful
    } on TimeoutException {
      // If a TimeoutException takes place

      _currentConnectionAttempts++;
      // The current number of connection attempts increases by 1
    } on SocketException {
      // If a SocketException takes place

      _currentConnectionAttempts++;
      // The current number of connection attempts increases by 1
    }

    notifyListeners();
    // Notifies any widgets or services listening to this class that a change took place
    // Specifically, that the connection status changed
    // It does it through ChangeNotifier

    return false;
    // If the try block fails and the connection is not established, the method returns false
    // false = connection was not established
  }

  // -------- disconnect() method --------
  // Used to end the connection and reset the connection state
  void disconnect() {
    _client?.close();
    // Attempts to close the connection to the Liquid Galaxy (if it exists)
    // ? is used to safely call close() ONLY if _client is NOT null (in other words, ONLY if a connection exists)
    // .close() is a method provided by SSHClient that closes the connection with the remote server

    _client = null;
    // If _client = null, this indicates that there is no current connection to the Liquid Galaxy anymore

    _isConnected = false;
    // _isConnected = false tells the rest of the application that there is no current connection to the Liquid Galaxy anymore

    notifyListeners();
    // Notifies any widgets or services listening to this class that a change took place
    // Specifically, that the connection status changed
    // It does it through ChangeNotifier
  }

  // -------- execute() method --------
  // Used to send a command to the Liquid Galaxy
  Future<bool> execute(String command, String successMessage) async {
    // Defines an asynchronous method that returns a boolean value
    // 'async' allows to use 'await' inside the function
    // It also takes two parameters
    // 'command' is the SSH command that will be sent to the Liquid Galaxy
    // 'successMessage' is a message to log if the command is successful

    if (_client == null) {
      // Checks if _client is null, which would mean there is currently no connection to the Liquid Galaxy

      debugPrint('SSH client NOT connected');
      // If this is true, prints 'SSH client NOT connected' in the debug console
      // NOT visible to users, only to developers through the debug console

      return false;
      // Since there is no client to send the command to, exits the methods
    }

    // If THERE IS a connection to the Liquid Galaxy:

    try {
      // try block used to catch any exceptions that may occur

      final session = await _client!.execute(command);
      // ! indicates that _client is NOT null
      // Calls the execute() method and uses it to send the command that was introduced
      // await pauses the method until the command is initiated

      await session.done;
      // Wait for the session to complete to ensure the channel is closed

      debugPrint(successMessage);
      // Prints the success message that was introduced as a parameter in the debug console
      // NOT VISIBLE TO USERS, only to developers in the debug console

      return true;
      // Returns true to indicate the command finished executing
    } catch (e) {
      // Catches any errors thrown during the try block

      debugPrint('There was an error executing the command: $e');
      // Prints the specific error on the debug console
      // NOT VISIBLE TO USERS, only to developers in the debug console

      return false;
      // Since the command execution failed, it retuns false
    }
  }

  // -------- query() method --------
  // Used to send a text-based query to the Liquid Galaxy by writing it into a temporary file on the remote system
  // A query is basically a text string
  Future<bool> query(String content) async {
    // Defines an asynchronous method that returns a boolean value
    // 'async' allows to use 'await' inside the function
    // It also takes a parameter called 'content'
    // This parameter is the text we want to send as a query

    final result = await execute(
      // Calls the execute() method previously defined in this file

      'echo "$content" > /tmp/query.txt',
      // This is the 'command' parameter from the execute() method
      // What it does is write the message from the 'content' parameter into the file /tmp/query.txt on the remote Liquid Galaxy machine
      // echo "$content" outputs the text
      // > redirects it into the file
      // This file is read by the Liquid Galaxy system to trigger actions depending on its content

      'Query sent: $content',
      // This is the 'successMessage' parameter from the execute() method
      // In this case, if the method is successful it prints the query that was sent on the debug console
    );
    return result;
    // Returns true if the execute() method returned true (for example, the command was successful)
    // Returns false otherwise
  }

  // -------- calculateRightMostScreen() method --------
  // Used to calculate the screen that is positioned the furthest to the right in the Liquid Galaxy rig
  int calculateRightMostScreen(int screenCount) {
    // This method needs a parameter called 'screenCount', which is the total number of screens in the rig

    return screenCount == 1 ? 1 : (screenCount / 2).floor() + 1;
    // For this, it uses a ternary operator, which works with the following structure:
    // condition ? valueIfTrue : valueIfFalse
    // If there is only 1 screen (screenCount == 1), the screen furthest to the right is 1
    // If there is more than 1 screen, divides the total number of screens by 2 (screenCount / 2)
    // Then rounds it down (.floor()) and adds 1 (+ 1)
  }

  // -------- calculateLeftMostScreen() method --------
  // Used to calculate the screen that is positioned the furthest to the left in the Liquid Galaxy rig
  int calculateLeftMostScreen(int screenCount) {
    // This method needs a parameter called 'screenCount', which is the total number of screens in the rig

    return screenCount == 1 ? 1 : (screenCount / 2).floor() + 2;
    // For this, it uses a ternary operator, which works with the following structure:
    // condition ? valueIfTrue : valueIfFalse
    // If there is only 1 screen (screenCount == 1), the screen furthest to the right is 1
    // If there is more than 1 screen, divides the total number of screens by 2 (screenCount / 2)
    // Then rounds it down (.floor()) and adds 2 (+ 2)
  }

  // -------- _forceRefresh() method --------
  // Used to force a KML refresh on an specific screen
  // In order to do so, it adds a refresh interval to its KML configuration file
  // After a short delay it removes this interval, returning to the original state

  Future<void> forceRefresh(int screenNumber) async {
    // Defines an asynchronous method that does not return any value (void)
    // 'async' allows to use 'await' inside the function
    // It does not return any value because its function is to trigger a side-effect, not to return data
    // It also takes a parameter called 'screenNumber'
    // This parameter is the number of screens of the Liquid Galaxy rig we are working with

    try {
      // try block used to catch any exceptions that may occur

      final search =
          '<href>##LG_PHPIFACE##kml\\/slave_$screenNumber.kml<\\/href>';
      // The 'search' variable stores the XML pattern to find the KML reference for the specified screen
      // <href> is the tag that marks the start of a hyperlink reference (</href> marks the end)
      // ##LG_PHPIFACE## is a placeholder inside the URL that allows the KML files to refer to resources hosted on the Liquid Galaxy system
      // kml\\/slave_$screenNumber.kml is the path to a KML file inside the system
      // kml/ is a folder
      // slave_$screenNumber.kml is the file name
      // $screenNumber is a variable that will be replace by the actual number of screens of the rig
      // \\/ is an escaped forward slash
      // Since this string will be used inside a 'sed' command, the forward slash / must be escaped as \/ to be treated literally in the pattern
      // A 'sed' command is command line used on Linux systems to process and transform text in files or streams
      // It reads input text line by line, can search for patterns, and can replace, delete, insert or modify text based on those patterns

      final replace =
          '<href>##LG_PHPIFACE##kml\\/slave_$screenNumber.kml<\\/href><refreshMode>onInterval<\\/refreshMode><refreshInterval>1<\\/refreshInterval>';
      // The 'replace' variable stores the XML pattern that adds refreshMode and refreshInterval tags to enable a periodic refresh every second
      // <href> is the tag that marks the start of a hyperlink reference (</href> marks the end)
      // ##LG_PHPIFACE## is a placeholder inside the URL that allows the KML files to refer to resources hosted on the Liquid Galaxy system
      // kml\\/slave_$screenNumber.kml is the path to a KML file inside the system
      // kml/ is a folder
      // slave_$screenNumber.kml is the file name
      // $screenNumber is a variable that will be replace by the actual number of screens of the rig
      // \\/ is an escaped forward slash
      // Since this string will be used inside a 'sed' command, the forward slash / must be escaped as \/ to be treated literally in the pattern
      // A 'sed' command is command line used on Linux systems to process and transform text in files or streams
      // It reads input text line by line, can search for patterns, and can replace, delete, insert or modify text based on those patterns

      // After the closing </href> tag, it adds two new XML tags:
      // <refreshMode>onInterval<\\/refreshMode> enables automatic refreshing of this KML file on a specific interval
      // <refreshInterval>1<\\/refreshInterval> sets this interval to 1 second of duration
      // This replacement pattern allows the system to force the screen to reload its KML data periodically
      // This is useful for updating content dynamically

      final addCommand =
          'echo ${_lgConnectionModel.password} | sudo -S sed -i "s|$search|$replace|" ~/earth/kml/slave/myplaces.kml';
      // The 'addCommand' variable stores the shell command that will be run remotely on the Liquid Galaxy, in this case to add refresh instructions
      // echo ${_lgConnectionModel.password} outputs the password stored in the connection model
      // The pipe symbol (|) sends that password as an input to the next command (sudo)
      // sudo -S runs the following command with root (superuser) privileges, reading the password from standard input (-S)
      // sed -i runs the 'sed' command with the '-i' flag, which means it directly modifies the file

      // "s|$search|$replace|" is the 'sed' substitution command ("s|pattern|replacement|")
      // s means substitute
      // | is used as a delimiter (instead of /) to avoid conficts with slashes in the search and replace patterns
      // $search is the pattern to find the original KML reference (which we stored in the 'search' variable)
      // $replace is the replacement pattern (which we stored in the 'replace' variable) with added refresh tags

      // ~/earth/kml/slave/myplaces.kml is the path to the KML file that will be edited on the remote system
      // To sump up, this command replaces the existing KML file reference with a new one that includes the refresh instructions
      // This forces the screen to refresh preiodically

      await execute(
        // Executes the execute() method remotely on the specified screen
        // 'await' pauses execution until

        "sshpass -p ${_lgConnectionModel.password} ssh -t lg$screenNumber '$addCommand'",
        // This is the value of the 'command' parameter
        // sshpass -p ${_lgConnectionModel.password} provides the password automatically (without user input)
        // ssh -t forces a pseudo-terminal (a virtual terminal window) allocation, making the remote server think we are typing from a real terminal
        // This makes sure that commands that depend on environment can still run
        // lg$screenNumber is the hostname or user@host for the specific screen we want to target
        // '$addCommand' is the actual command we want to run on a specific screen, in this case the command use to add the refresh instructions

        'Refresh interval added to screen $screenNumber',
        // This is the 'successMessage' parameter from the execute() method
        // In this case, confirms a refresh interval has been added to a specific screen (and the number correspondant to this screen)
      );

      await Future.delayed(const Duration(seconds: 1));
      // Waits 1 second to allow the system to apply the KML refresh update before restoring the original content
      // Future.delayed creates a Future (a value that will be available at some point in the future) that completes after a specified delay
      // const Duration(seconds: 1) specifies the length of that delay
      // 'await' pauses execution until the delay is over

      final searchWithRefresh =
          '<href>##LG_PHPIFACE##kml\\/slave_$screenNumber.kml<\\/href><refreshMode>onInterval<\\/refreshMode><refreshInterval>[0-9]+<\\/refreshInterval>';
      // The 'searchWithRefresh' variable stores the pattern used to find and remove the auto-refresh instructions after they have been temporaly added
      // <href> is the tag that marks the start of a hyperlink reference (</href> marks the end)
      // ##LG_PHPIFACE## is a placeholder inside the URL that allows the KML files to refer to resources hosted on the Liquid Galaxy system
      // kml\\/slave_$screenNumber.kml is the path to a KML file inside the system
      // kml/ is a folder
      // slave_$screenNumber.kml is the file name
      // $screenNumber is a variable that will be replace by the actual number of screens of the rig
      // \\/ is an escaped forward slash
      // Since this string will be used inside a 'sed' command, the forward slash / must be escaped as \/ to be treated literally in the pattern
      // A 'sed' command is command line used on Linux systems to process and transform text in files or streams
      // It reads input text line by line, can search for patterns, and can replace, delete, insert or modify text based on those patterns
      // After the closing </href> tag, it adds two new XML tags:
      // <refreshMode>onInterval<\\/refreshMode> enables automatic refreshing of this KML file on a specific interval

      // <refreshInterval>[0-9]+<\\/refreshInterval> establishes the duration of this interval
      // [0-9] is a character class that matches any digit from 0 to 9
      // + is a quantifier that means "one or more times"
      // [0-9]+ basically means "match one or more digits", and is useful when we don't know in advance the current refresh internal value
      // This means that this pattern (<refreshInterval>[0-9]+<\\/refreshInterval>) would match:
      // <refreshInterval>1<\\/refreshInterval>, <refreshInterval>100<\\/refreshInterval>, <refreshInterval>999999<\\/refreshInterval>, etc.

      final restore =
          '<href>##LG_PHPIFACE##kml\\/slave_$screenNumber.kml<\\/href>';
      // The 'restore' variable stores the original KML reference without any refresh interval tags
      // This is used to restore the file back to its original state
      // Even though the content is the same as the 'search' variable, their objectives are different
      // The 'search' variable is used to detect the clean line before adding refresh
      // The 'restore' variable is used to bring it bac to the original state

      // The 'search' variable stores the XML pattern to find the KML reference for the specified screen
      // <href> is the tag that marks the start of a hyperlink reference (</href> marks the end)
      // ##LG_PHPIFACE## is a placeholder inside the URL that allows the KML files to refer to resources hosted on the Liquid Galaxy system
      // kml\\/slave_$screenNumber.kml is the path to a KML file inside the system
      // kml/ is a folder
      // slave_$screenNumber.kml is the file name
      // $screenNumber is a variable that will be replace by the actual number of screens of the rig
      // \\/ is an escaped forward slash
      // Since this string will be used inside a 'sed' command, the forward slash / must be escaped as \/ to be treated literally in the pattern
      // A 'sed' command is command line used on Linux systems to process and transform text in files or streams
      // It reads input text line by line, can search for patterns, and can replace, delete, insert or modify text based on those patterns

      final removeCommand =
          'echo ${_lgConnectionModel.password} | sudo -S sed -i "s|$searchWithRefresh|$restore|" ~/earth/kml/slave/myplaces.kml';
      // The 'removeCommand' variable stores the shell command that will be run remotely on the Liquid Galaxy, in this case to remove refresh instructions
      // echo ${_lgConnectionModel.password} outputs the password stored in the connection model
      // The pipe symbol (|) sends that password as an input to the next command (sudo)
      // sudo -S runs the following command with root (superuser) privileges, reading the password from standard input (-S)
      // sed -i runs the 'sed' command with the '-i' flag, which means it directly modifies the file

      // "s|$searchWithRefresh|$restore|" is the 'sed' substitution command ("s|pattern|replacement|")
      // s means substitute
      // | is used as a delimiter (instead of /) to avoid conficts with slashes in the search and replace patterns
      // $searchWithRefresh is the pattern used to find and remove the auto-refresh instructions (which we stored in the 'searchWithRefresh' variable)
      // $restore is the replacement pattern, in this case the original file (which we stored in the 'restore' variable)
      // ~/earth/kml/slave/myplaces.kml is the path to the KML file that will be edited on the remote system
      // To sump up, this command removes the <refreshMode> and <refreshInterval> tags that were added to force a KML refresh
      // It does it by finding the string with the refresh settings and replace it with the clean and original line

      await execute(
        // Executes the execute() method remotely on the specified screen
        // 'await' pauses execution until the execute() method is successfully executed

        "sshpass -p ${_lgConnectionModel.password} ssh -t lg$screenNumber '$removeCommand'",
        // This is the value of the 'command' parameter
        // sshpass -p ${_lgConnectionModel.password} provides the password automatically (without user input)
        // ssh -t forces a pseudo-terminal (a virtual terminal window) allocation, making the remote server think we are typing from a real terminal
        // This makes sure that commands that depend on environment can still run
        // lg$screenNumber is the hostname or user@host for the specific screen we want to target
        // '$removeCommand' is the actual command we want to run on a specific screen, in this case the command use to remove the refresh instructions

        'Refresh interval removed from screen $screenNumber',
        // This is the 'successMessage' parameter from the execute() method
        // In this case, confirms a refresh interval has been removed from a specific screen (and the number correspondant to this screen)
      );
    } catch (e) {
      // Catches any errors thrown during the try block

      debugPrint('Error in _forceRefresh: $e');
      // Prints the specific error on the debug console
      // NOT VISIBLE TO USERS, only to developers in the debug console
    }
  }

  // -------- flyTo() method --------
  // Used to "fly" (move) the Liquid Galaxy camera to a specific location defined by a KML viewtag
  Future<void> flyTo(String kmlViewTag) async {
    // Defines an asynchronous method that does not return any value (void)
    // 'async' allows to use 'await' inside the function
    // It does not return any value because its function is to trigger a side-effect, not to return data
    // It also takes a parameter called 'kmlViewTag'
    // This parameter is expected to be a <LookAt> or <Camera> tag, which defines a camera movement or a view to fly to

    await query('flytoview=$kmlViewTag');
    // Executes the query() method
    // In this case, the value of the 'content' parameter is 'flytoview=$kmlViewTag'
    // flytoview= is a command recognized by Liquid Galaxy to trigger a camera movement to a specified location
    // In this case, it moves to the location that was specified in the flyto() call (kmlViewTag)
    // What this does is create an file on the Liquid Galaxy node (/tmp/query.txt) that will be read to update the view
    // In this case, await pauses the execution of the flyTo() method until the query() method has been executed
  }

  // -------- handleDisconnection() method --------
  // Used to react to a not expected disconnection to Liquid Galaxy and attempt reconnecting
  void _handleDisconnection() {
    _isConnected = false;
    // Sets the _isConnected variable to false, since there is no connection going on if the system is disconnected

    _client?.close();
    // Attempts to close the connection to the Liquid Galaxy (if it exists)
    // ? is used to safely call close() ONLY if _client is NOT null (in other words, ONLY if a connection exists)
    // .close() is a method provided by SSHClient that closes the connection with the remote server

    _client = null;
    // If _client = null, this indicates that there is no current connection to the Liquid Galaxy anymore

    _isTrailPlaying = false;
    // Sets the _isConnected variable to false because, when disconnecting, there is no connection but also no attempt to connect going on
    // If there is no attempt to connect going on, then there is no animation either

    _orbitPlaying = false;
    // Sets the _orbitPlaying variable to false because, when disconnecting, there is no connection but also no attempt to connect going on
    // If there is no attempt to connect going on, then there is no animation either

    _orbitTimer?.cancel();
    // Cancels the timer used for orbit animation updates (if one is running)
    // ? is used to safely call cancel() ONLY if _orbitTimer is NOT null (in other words, ONLY if an orbit animation is running)

    notifyListeners();
    // Notifies any widgets or services listening to this class that a change took place
    // Specifically, that the connection status changed
    // It does it through ChangeNotifier

    if (_currentConnectionAttempts < _maxConnectionAttempts) {
      // Checks if the current number of connection attempts has reached the maximum (5 in this case)
      // If this maximum number has NOT been reached yet:

      Future.delayed(const Duration(seconds: 3), () {
        // Waits 3 seconds to until trying to attempt to reconnect
        // Future.delayed creates a Future (a value that will be available at some point in the future) that completes after a specified delay
        // const Duration(seconds: 3) specifies the length of that delay

        connectToLG();
        // Calls the connectToLG() method to try reconnect to the Liquid Galaxy
      });
    }
  }

  // -------- startConnectionCheck() method --------
  // Used to start to check if the application is still connected to the Liquid Galaxy
  void _startConnectionCheck() {
    _connectionTimer?.cancel();
    // _connectionTimer (defined in the next line) is the variable that stores the periodic timer used to check if the application is still connected
    // If it already exists, it cancels it in order to avoid duplicates
    // ? is used to safely call cancel() ONLY if _connectionTimer is NOT null

    _connectionTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // Starts a new periodic timer that runs (in this case) every 5 seconds
      // This means that the next block of code will execute every 5 seconds

      if (!_isCheckingConnection) {
        // If a check is already in progress (_isCheckingConnection = true), skips this next line because there is no need to start a new check

        _checkConnection();
        // If there is no check going on, calls the _checkConnection() method to validate the connection
      }
    });
  }

  // -------- checkConnection() method --------
  // Used to create a timer that is used to check if the connection is still active
  Future<void> _checkConnection() async {
    // Defines an asynchronous method that does not return any value (void)
    // 'async' allows to use 'await' inside the function
    // It does not return any value because its function is to trigger a side-effect, not to return data

    if (_client == null || _isCheckingConnection) return;
    // Checks if the client is null (_client == null) or if a connection check is already going on (_isCheckingConnection)
    // Uses the OR (||) operator for this
    // If _client = null, this means there is no active connection, so we cannot check anything
    // If _isCheckingConnection is true, this means a check is already going on, so we exit the function (return) in order to avoid duplicates

    // If both of these conditions are not true, this means there is an active connection but no check going on
    _isCheckingConnection = true;
    // What we do then is start a connection check

    try {
      // try block used to catch any exceptions that may occur

      await _client!.execute('echo "ping"').timeout(const Duration(seconds: 3));
      // This line is used to send a test command to the Liquid Galaxy client
      // await waits for the execute() command to finish before moving on
      // ! is used to make sure that _client is not null
      // execute() is the method used to send a command to the Liquid Galaxy
      // In this case, the command is echo "ping", which sends the "ping" to the remote terminal
      // If the connection is alive, the terminal will reply with "ping"
      // .timeout(const Duration(seconds: 3)) adds a TimeOut of 3 seconds to the command
      // If the remote echo command takes more than 3 seconds, a TimeoutException is thrown

      _isConnected = true;
      // If the execute() method is successfully executed, _isConnected is set to true
      // This indicates the connection is alive and working
    } catch (e) {
      // Catches any errors thrown during the try block

      _handleDisconnection();
      // Calls the handleDisconnection() method handle any disconnection errors
    } finally {
      // The finally block ALWAYS runs (whether the try block succeeded or the catch block ran due to an error)

      _isCheckingConnection = false;
      // This line is important because, if we don't make sure that _isCheckingConnection is false, the next call to _checkConnection() may be skipped

      notifyListeners();
      // Notifies any widgets or services listening to this class that a change took place
      // Specifically, that the connection status changed
      // It does it through ChangeNotifier
    }
  }

  // -------- cleanKML() method --------
  // Used to clear KML related data from the Liquid Galaxy rig and refresh the display
  Future<bool> cleanKML() async {
    // Defines an asynchronous method that returns a boolean value
    // 'async' allows to use 'await' inside the function

    bool allSuccessful = true;
    // The 'allSuccessful' variable is used to track if all the commands succeeded
    // It is initialized to true because we assumme everything will succeed
    // After every command, we check if the value is still true

    final clearCommand =
        'echo "exittour=true" > /tmp/query.txt && > /var/www/html/kmls.txt';
    // The 'clearCommand' variable is used to store the line that resets or clears specific files as part of cleaning the KML state
    // echo "exittour=true" > /tmp/query.txt writes the "exittour=true" string into the /tmp/query.txt file
    // > is the operator that redirects the output ("exittour=true") into the file, overwriting the content
    // This string tells the Liquid Galaxy setup to exit any ongoing orbit (tour) mode
    // && is the AND operator (the second command only runs if the first one succeeds)
    // > /var/www/html/kmls.txt empties (clears) the kmls.txt file
    // The > operator with no content before it clears the file

    final headerCleared = await execute(
      // Executes the execute() method remotely on the specified screen
      // 'await' pauses execution until the execute() method is successfully executed
      // The result is stored in the 'headerCleared' variable

      clearCommand,
      // This is the value of the 'command' parameter
      // In this case, is the value of the 'clearCommand' variable that was defined earlier
      // This variable has the line to clear the KMLs

      'KMLs.txt cleared',
      // This is the 'successMessage' parameter from the execute() method
      // In this case, confirms the KML were cleared
    );

    allSuccessful = allSuccessful && headerCleared;
    // Used to track if all operations have bee successful so far
    // If allSuccessful is still true, the command continues
    // headerCleared checks if the 'headerCleared' variable (which stores the result of the execute() method) is true or not
    // If it is true, the command was successful
    // The value of this command (true or false) is updated in the 'allSuccessful' variable
    // If allSuccessful is still true, everything is going okay until now

    int rightMost = calculateRightMostScreen(_lgConnectionModel.screens);
    // Calculates which screen is the furthest to the right and stores it in the 'rightMost' variable

    const blankKml =
        '''<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2">
        <Document><name>Empty</name></Document></kml>''';
    // blankKml is a variable that holds an empty KML file that will be later sent to one of the screens
    // '''...''' is a Dart syntax that allows to divide this line into multiple ones to view it better (it is not part of the command per se)
    // <?xml version="1.0" encoding="UTF-8"?> tells the parser that this is an XML file encoded using UTF-8
    // <kml xmlns="http://www.opengis.net/kml/2.2"> is the root tag for a KML file
    // xmlns defines the namespace, which is used to identify elements in an XML file
    // In this case, the URL "http://www.opengis.net/kml/2.2" is the namespace URI for the official KML 2.2 standard
    // <Document>...</Document> is a container for KML features
    // <name>Empty</name> gives the document the title of "Empty", but nothing else

    final cleared = await execute(
      // Executes the execute() method remotely on the specified screen
      // 'await' pauses execution until the execute() method is successfully executed
      // The result is stored in the 'cleared' variable

      "echo '$blankKml' > /var/www/html/kml/slave_$rightMost.kml",
      // This is the value of the 'command' parameter
      // echo '$blankKml' outputs the content of the blankKml string
      // > /var/www/html/kml/slave_$rightMost.kml redirects that output into a file called slave_$rightMost.kml
      // $rightMost is replaced to the number correspondant to the furthest right screen
      // This line overwrites the existing KML file on that screen with a blank KML file (which "clears" it)

      'Rightmost screen cleared',
      // This is the 'successMessage' parameter from the execute() method
      // In this case, confirms the rightmost screen was cleared
    );

    allSuccessful = allSuccessful && cleared;
    // Used to track if all operations have bee successful so far
    // If allSuccessful is still true, the command continues
    // cleared checks if the 'cleared' variable (which stores the result of the execute() method) is true or not
    // If it is true, the command was successful
    // The value of this command (true or false) is updated in the 'allSuccessful' variable
    // If allSuccessful is still true, everything is going okay until now

    await forceRefresh(rightMost);
    // Forces a refresh on the screen furthest to the right using the forceRefresh() method we defined earlier
    // await makes sure the forceRefresh() method finishes executing before moving to the next line

    return allSuccessful;
    // Returns the final result of the cleanKML() method
    // If allSuccessful = true, all operations were successful
    // If allSuccessful = false, something failed at some point
  }

  // -------- cleanLogos() method --------
  // Used to clear any logos (images or graphics related to the KML) from the screen
  Future<void> cleanLogos() async {
    // Defines an asynchronous method that does not return any value (void)
    // 'async' allows to use 'await' inside the function
    // It does not return any value because its function is to trigger a side-effect, not to return data

    int leftMost = calculateLeftMostScreen(_lgConnectionModel.screens);
    // Calculates which screen is the furthest to the left and stores it in the 'leftMost' variable

    const blankKml =
        '''<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2">
        <Document><name>Logo</name></Document></kml>''';
    // blankKml is a variable that holds an empty KML file that will be later sent to one of the screens
    // '''...''' is a Dart syntax that allows to divide this line into multiple ones to view it better (it is not part of the command per se)
    // <?xml version="1.0" encoding="UTF-8"?> tells the parser that this is an XML file encoded using UTF-8
    // <kml xmlns="http://www.opengis.net/kml/2.2"> is the root tag for a KML file
    // xmlns defines the namespace, which is used to identify elements in an XML file
    // In this case, the URL "http://www.opengis.net/kml/2.2" is the namespace URI for the official KML 2.2 standard
    // <Document>...</Document> is a container for KML features
    // <name>Logo</name> gives the document the title of "Logo", but nothing else

    await execute(
      // Executes the execute() method remotely on the specified screen
      // 'await' pauses execution until the execute() method is successfully executed

      "echo '$blankKml' > /var/www/html/kml/slave_$leftMost.kml",
      // This is the value of the 'command' parameter
      // echo '$blankKml' outputs the content of the blankKml string
      // > /var/www/html/kml/slave_$leftMost.kml redirects that output into a file called slave_$leftMost.kml
      // $leftMost is replaced to the number correspondant to the furthest left screen
      // This line overwrites the existing KML file on that screen with a blank KML file (which "clears" it)

      'KML logo cleared',
      // This is the 'successMessage' parameter from the execute() method
      // In this case, it confirms that the KML logo (image or graphic) was successfully cleared
    );
    await forceRefresh(leftMost);
    // Forces a refresh on the screen furthest to the left using the forceRefresh() method we defined earlier
    // await makes sure the forceRefresh() method finishes executing before moving to the next line
  }

  // -------- cleanBalloonKML() method --------
  // Used to clear any balloon content (related to KML)
  // A balloon in this context is a pop-up box that appears when you click on a placemark

  Future<void> cleanBalloonKML() async {
    // Defines an asynchronous method that does not return any value (void)
    // 'async' allows to use 'await' inside the function
    // It does not return any value because its function is to trigger a side-effect, not to return data

    int rightMost = calculateRightMostScreen(_lgConnectionModel.screens);
    // Calculates which screen is the furthest to the right and stores it in the 'rightMost' variable

    const blankKml =
        '''<?xml version="1.0" encoding="UTF-8"?><kml xmlns="http://www.opengis.net/kml/2.2">
        <Document><name>Balloon</name></Document></kml>''';
    // blankKml is a variable that holds an empty KML file that will be later sent to one of the screens
    // '''...''' is a Dart syntax that allows to divide this line into multiple ones to view it better (it is not part of the command per se)
    // <?xml version="1.0" encoding="UTF-8"?> tells the parser that this is an XML file encoded using UTF-8
    // <kml xmlns="http://www.opengis.net/kml/2.2"> is the root tag for a KML file
    // xmlns defines the namespace, which is used to identify elements in an XML file
    // In this case, the URL "http://www.opengis.net/kml/2.2" is the namespace URI for the official KML 2.2 standard
    // <Document>...</Document> is a container for KML features
    // <name>Balloon</name> gives the document the title of "Balloon", but nothing else

    await execute(
      // Executes the execute() method remotely on the specified screen
      // 'await' pauses execution until the execute() method is successfully executed

      "echo '$blankKml' > /var/www/html/kml/slave_$rightMost.kml",
      // This is the value of the 'command' parameter
      // echo '$blankKml' outputs the content of the blankKml string
      // > /var/www/html/kml/slave_$rightMost.kml redirects that output into a file called slave_$rightMost.kml
      // $rightMost is replaced to the number correspondant to the furthest right screen
      // This line overwrites the existing KML file on that screen with a blank KML file (which "clears" it)

      'KML balloon cleared',
      // This is the 'successMessage' parameter from the execute() method
      // In this case, it informs that the balloons were successfully cleared from the screen
    );
    await forceRefresh(rightMost);
    // Forces a refresh on the screen furthest to the right using the forceRefresh() method we defined earlier
    // await makes sure the forceRefresh() method finishes executing before moving to the next line
  }

  // -------- cleanAll() method --------
  // Used to clear all active content and animations from the Liquid Galaxy rig
  Future<bool> cleanAll() async {
    // Defines an asynchronous method that returns a boolean value
    // 'async' allows to use 'await' inside the function

    try {
      // try block used to catch any exceptions that may occur

      _orbitTimer?.cancel();
      // Cancels the timer used for orbit animation updates (if one is running)
      // ? is used to safely call cancel() ONLY if _orbitTimer is NOT null (in other words, ONLY if an orbit animation is running)

      _connectionTimer?.cancel();
      // _connectionTimer (defined in the next line) is the variable that stores the periodic timer used to check if the application is still connected
      // If it already exists, it cancels it in order to avoid duplicates
      // ? is used to safely call cancel() ONLY if _connectionTimer is NOT null

      if (_isTrailPlaying) await trailStop();
      // If a trail animation is currently playing, it stops it using the trailStop() method
      // A trail animation is an animated path that represents the movement of an object

      if (_orbitPlaying) await orbitStop();
      // If am orbit animation is currently playing, it stops it using the orbitStop() method

      await Future.wait([
        // Runs all three methods to clear the screens in parallel and waits for them to finish before continuing

        cleanKML(),
        // Cleans the KML files

        cleanLogos(),
        // Cleans the KML logos

        cleanBalloonKML(),
        // Cleans the KML balloons
      ]);

      _isTrailPlaying = false;
      // Updates the isTrailPlaying to false because the trail animation has stopped

      _orbitPlaying = false;
      // Updates the orbitPlaying to false because the orbit animation has stopped

      final screens = List.generate(_lgConnectionModel.screens, (i) => i + 1);
      // Creates a list of all screen numbers on the Liquid Galaxy rig and stores it in the 'screens' variable
      // List.generate(count, generatorFunction) creates a list with 'count' number of items using the 'generatorFunction' function
      // In this case, counter = _lgConnectionModel.screens and generatorFunction = (i) => i + 1
      // lgConnectionModel.screens holds the total number of screens in the Liquid Galaxy rig
      // (i) => i + 1 is a function that generates numbers starting from 1 (instead of the default 0)
      // If i = 0, i + 1 = 1
      // If i = 1, i + 1 = 2, etc.
      // If lgConnectionModel.screens = 5, final screens = List.generate(5, (i) => i + 1)
      // This results in screens = [1, 2, 3, 4, 5]

      await Future.wait(screens.map(forceRefresh));
      // Calls the forceRefresh() method for each screen to refresh them and waits for them to finish before continuing
      // screens.map(_forceRefresh) applies the method to each screen
      // Future.wait runs all the executions in parallel

      notifyListeners();
      // Notifies any widgets or services listening to this class that a change took place
      // Specifically, that the connection status changed
      // It does it through ChangeNotifier

      return true;
      // If the execution was successful, returns true
    } catch (e) {
      // Catches any errors thrown during the try block

      debugPrint('Error during cleanAll: $e');
      // Prints the specific error on the debug console
      // NOT VISIBLE TO USERS, only to developers in the debug console

      _isTrailPlaying = false;
      // Updates the isTrailPlaying to false because the trail animation has stopped

      _orbitPlaying = false;
      // Updates the orbitPlaying to false because the orbit animation has stopped

      notifyListeners();
      // Notifies any widgets or services listening to this class that a change took place
      // Specifically, that the connection status changed
      // It does it through ChangeNotifier

      return false;
      // Since the execution failed, it returns false
    }
  }

  // -------- trailStop() method --------
  // Used to stop the current trail animation in the Liquid Galaxy
  Future<void> trailStop() async {
    // Defines an asynchronous method that does not return any value (void)
    // 'async' allows to use 'await' inside the function
    // It does not return any value because its function is to trigger a side-effect, not to return data

    _orbitTimer?.cancel();
    // Cancels the timer used for orbit animation updates (if one is running)
    // ? is used to safely call cancel() ONLY if _orbitTimer is NOT null (in other words, ONLY if an orbit animation is running)

    _isTrailPlaying = false;
    // Updates the isTrailPlaying to false because the trail animation has stopped

    notifyListeners();
    // Notifies any widgets or services listening to this class that a change took place
    // Specifically, that the connection status changed
    // It does it through ChangeNotifier

    await forceRefresh(1);
    // Forces refresh on screen number 1 (usually the master one) to reflect the trail animation has stopped
    // Since this is usually the master one, other screens will sync with it
    // 'await' pauses execution until the execute() method is successfully executed
  }

  // -------- orbitStop() method --------
  // Used to stop the current orbit animation in the Liquid Galaxy
  Future<void> orbitStop() async {
    // Defines an asynchronous method that does not return any value (void)
    // 'async' allows to use 'await' inside the function
    // It does not return any value because its function is to trigger a side-effect, not to return data

    _orbitTimer?.cancel();
    // Cancels the timer used for orbit animation updates (if one is running)
    // ? is used to safely call cancel() ONLY if _orbitTimer is NOT null (in other words, ONLY if an orbit animation is running)

    _orbitPlaying = false;
    // Updates the orbitPlaying to false because the orbit animation has stopped

    notifyListeners();
    // Notifies any widgets or services listening to this class that a change took place
    // Specifically, that the connection status changed
    // It does it through ChangeNotifier

    await query('exittour=true');
    // Uses the query method to send the 'exittour=true' string to the system
    // This string tells the Liquid Galaxy setup to exit any ongoing orbit (tour) mode
    // 'await' pauses execution until the query() method is successfully executed
  }

  // -------- reboot() method --------
  // Used to reboot all the screens in a Liquid Galaxy setup
  Future<bool> reboot() async {
    // Defines an asynchronous method that returns a boolean value
    // 'async' allows to use 'await' inside the function

    try {
      // try block used to catch any exceptions that may occur

      await connectToLG();
      // First of all, connects to the Liquid Galaxy system
      // This is important to make sure all commands can be sent to all screens
      // 'await' pauses execution until the connectToLG() method is successfully executed

      bool allSuccessful = true;
      // The 'allSuccessful' variable is used to track if all the commands succeeded
      // It is initialized to true because we assumme everything will succeed
      // After every command, we check if the value is still true

      await cleanAll();
      // Cleans all the KML files, logos and balloons and stops animations before rebooting
      // 'await' pauses execution until the connectToLG() method is successfully executed

      await Future.delayed(const Duration(seconds: 2));
      // Waits 2 seconds to let the cleaning finish before rebooting
      // Future.delayed creates a Future (a value that will be available at some point in the future) that completes after a specified delay
      // const Duration(seconds: 2) specifies the length of that delay

      for (int i = _lgConnectionModel.screens; i >= 1; i--) {
        // Loop that goes screen by screen (i) from the highest screen number (lgConnectionModel.screens) down to 1 (>= 1), decreasing one by one (i--)
        // For each screen:

        final rebootCommand =
            'sshpass -p ${_lgConnectionModel.password} ssh -t lg$i '
            '"echo ${_lgConnectionModel.password} | sudo -S reboot"';
        // Creates a command that will be used to reboot and that is stored in the 'rebootCommand' variable
        // sshpass -p ${_lgConnectionModel.password} provides the password automatically (without user input)
        // ssh -t lg$i runs SSH to connect to the host named lg$i (with i being the current screen number in the loop)
        // - t forces a pseudo-terminal (a virtual terminal window) allocation, making the remote server think we are typing from a real terminal
        // This makes sure that commands that depend on environment can still run
        // "echo ${_lgConnectionModel.password} | sudo -S reboot" is the remote command executed on the screen after connecting
        // echo ${_lgConnectionModel.password} outputs the password again
        // The pipe symbol (|) sends that password as an input to the next command (sudo)
        // sudo -S runs the following command with root (superuser) privileges, reading the password from standard input (-S)
        // sudo -S reboot runs the reboot command using the password

        final result = await execute(
          // Executes the execute() method remotely on the specified screen
          // 'await' pauses execution until the execute() method is successfully executed
          // The result is stored in the 'result' variable

          rebootCommand,
          // This is the value of the 'rebootCommand' parameter
          // In this case is the line used to reboot using admin privileges and without manual input of the password

      'Screen $i was successfully rebooted',
          // This is the 'successMessage' parameter from the execute() method
          // In this case, it informs that a screen ('i' will be substituted with the current screen number on the loop) was successfully rebooted
        );
 
        allSuccessful = allSuccessful && result;
        // Used to track if all operations have bee successful so far
        // If allSuccessful is still true, the command continues
        // result checks if the 'result' was true
        // If it is true, the command was successful
        // The value of this command (true or false) is updated in the 'allSuccessful' variable
        // If allSuccessful is still true, everything is going okay until now

        // ------------ Make sure the main node reboots ------------
        final rebootCommandLg1 =
            'sshpass -p ${_lgConnectionModel.password} ssh -t lg1 "echo ${_lgConnectionModel.password} | sudo -S reboot"';
        // Creates a command that will be used to make sure the main node rebooted and that is stored in the 'rebootCommand' variable
        // sshpass -p ${_lgConnectionModel.password} provides the password automatically (without user input)
        // ssh -t lg1 runs SSH to connect to the host named lg1 (with 1 being the screen number, screen 1 = main screen)
        // - t forces a pseudo-terminal (a virtual terminal window) allocation, making the remote server think we are typing from a real terminal
        // This makes sure that commands that depend on environment can still run
        // "echo ${_lgConnectionModel.password} | sudo -S reboot" is the remote command executed on the screen after connecting
        // echo ${_lgConnectionModel.password} outputs the password again
        // The pipe symbol (|) sends that password as an input to the next command (sudo)
        // sudo -S runs the following command with root (superuser) privileges, reading the password from standard input (-S)
        // sudo -S reboot runs the reboot command using the password

        final lg1RebootResult = await execute(
          // Executes the execute() method remotely on the main screen
          // 'await' pauses execution until the execute() method is successfully executed
          // The result is stored in the 'lg1RebootResult' variable

          rebootCommandLg1,
          // This is the value of the 'rebootCommand' parameter
          // In this case is the line used to reboot the main screen using admin privileges and without manual input of the password

          'The main screen was suceesfully rebooted',
          // This is the 'successMessage' parameter from the execute() method
          // In this case, it informs that the main screen was successfully rebooted
        );
 
        allSuccessful = allSuccessful && result && lg1RebootResult;
        // Used to track if all operations have bee successful so far
        // If allSuccessful is still true, the command continues
        // result checks if the individual screen result was true
        // lg1RebootResult checks if the main screen reboot result was true
        // If they are true, the command was successful
        // The value of this command (true or false) is updated in the 'allSuccessful' variable
        // If allSuccessful is still true, everything is going okay until now
      }

      _isConnected = false;
      // Updates the value of _isConnected to false because at this point the connection was lost

      _client?.close();
      // Attempts to close the connection to the Liquid Galaxy (if it exists)
      // ? is used to safely call close() ONLY if _client is NOT null (in other words, ONLY if a connection exists)
      // .close() is a method provided by SSHClient that closes the connection with the remote server

      _client = null;
      // If _client = null, this indicates that there is no current connection to the Liquid Galaxy anymore

      notifyListeners();
      // Notifies any widgets or services listening to this class that a change took place
      // Specifically, that the connection status changed
      // It does it through ChangeNotifier

      Future.delayed(const Duration(seconds: 50), () async {
        // Waits 50 seconds to allow the rebooted system to come back online
        // Future.delayed creates a Future (a value that will be available at some point in the future) that completes after a specified delay
        // const Duration(seconds: 50) specifies the length of that delay

        _startConnectionCheck();
        // Calls the method that creates the timer to check if the connection to Liquid Galaxy is still active

        for (int i = 0; i < 10; i++) {
          // Loop that goes from 0 (i = 0) to 9 (i < 10) increasing one by one (i++)
          // Basically a loop that tries to reconnect 10 times
          // You can put any value for the times you allow to retry reconnection, but it is better if it is not too high

          if (await connectToLG() == true) {
            // We call the connectToLg() method to attempt reconnection and wait until it finishes
            // If successful (true):

            debugPrint('Successfully reconnected to the LG');
            // Prints the message 'Successfully reconnected to the LG' on the debug console
            // NOT VISIBLE TO USERS, only to developers in the debug console

            await flyTo(
                '<LookAt><longitude>-3.7492199</longitude><latitude>40.4636688</latitude><altitude>0</altitude><heading>0</heading><tilt>60</tilt><range>2000</range><altitudeMode>relativeToGround</altitudeMode></LookAt>');
            // flyTo() is a method we defined earlier that moves the Liquid Galaxy view
            // Everything is inside <LookAt>...</LookAt>, a tag that describes exactly where and how to position the virtual camera
            // <longitude>-3.7492199</longitude> is the longitude coordinate (you can choose any longitude you want, in this case is near Madrid, Spain)
            // <latitude>40.4636688</latitude> is the latitude (you can choose any latitude you want)
            // <altitude>0</altitude> is the altitude of the target point, NOT the altitude of the camera (0 means at ground level)
            // <heading>0</heading> is the direction the camera is facing (0 is north, 90 is east, 180 is south 270 is west, a value like 45 would be northeast)
            // <tilt>60</tilt> is the camera tilt angle from vertical (in this case is 60 degrees, but you can choose any value equal or superior to 45 degrees)
            // <range>2000</range> is the distance from the target point (the altitude of the camera)
            // In my case I chose 2000 meters, which is 2 km (you can choose any value you want, but it should be around 2 km)
            // <altitudeMode>relativeToGround</altitudeMode> means the altitude is measured relative to ground level

            break;
            // Stops any further connection attempts and exits the loop
          }

          await Future.delayed(const Duration(seconds: 5));
          // If the reconnection attempt failed, waits 5 seconds to try again
          // Future.delayed creates a Future (a value that will be available at some point in the future) that completes after a specified delay
          // const Duration(seconds: 5) specifies the length of that delay
        }
      });

      return allSuccessful;
      // Returns the final result of the cleanKML() method
      // If allSuccessful = true, all operations were successful
      // If allSuccessful = false, something failed at some point
    } catch (e) {
      // Catches any errors thrown during the try block

      debugPrint('There was an error during reboot: $e');
      // Prints the specific error on the debug console
      // NOT VISIBLE TO USERS, only to developers in the debug console

      _handleDisconnection();
      // If an error was caught it means the connection was lost, so we call the handleDisconnection() method to handle the situation

      return false;
      // Since the reboot was not successful, the value returned is false
    }
  }

  // -------- relaunchLG() method --------
  // Used to relaunch the connection to the Liquid Galaxy
  Future<bool> relaunchLG() async {
    // Defines an asynchronous method that returns a boolean value
    // 'async' allows to use 'await' inside the function

    final relaunchCmd = '''
        RELAUNCH_CMD="\\ 
        if [ -f /etc/init/lxdm.conf ]; 
          then
            export SERVICE=lxdm
        elif [ -f /etc/init/lightdm.conf ]; 
          then
            export SERVICE=lightdm
          else
            exit 1 
          fi
        if [[ \\\$(service \\\$SERVICE status) =~ 'stop' ]]; 
          then
            echo ${_lgConnectionModel.password} | sudo -S service \\\${SERVICE} start
          else
            echo ${_lgConnectionModel.password} | sudo -S service \\\${SERVICE} restart
          fi
        " && sshpass -p ${_lgConnectionModel.password} ssh -x -t lg@lg1 "\$RELAUNCH_CMD"''';
    // relaunchCmd is a variable that stores the command used to relaunch
    // '''...''' is a Dart syntax that allows to divide this line into multiple ones to view it better (it is not part of the command per se)
    // RELAUNCH_CMD="\\..." defines a Bash variable called "RELAUNCH_CMD"
    // \\ escapes the new line so Bash treats the script inside as one long logical command
    // ------------------------ Detect which display manager is running ------------------------
    // If [ -f /etc/init/lxdm.conf ]; detects if /etc/init/lxdm.conf exists
    // If it does, sets SERVICE=lxdm
    // If [ -f /etc/init/lightdm.conf ]; detects if /etc/init/lightdm.conf exists
    // If it does, sets SERVICE=lightdm
    // This is because Liquid Galaxy uses a Linux desktop manager to run its display windows and we need to know which one to restart
    // If none of these cases are true, exits with error (exit 1)
    // ------------------------ Start or restart the service ------------------------
    // $(service \\\$SERVICE status) =~ 'stop' checks if the service has currently stopped
    // If it has stopped, starts it or restarts it
    // echo ${_lgConnectionModel.password} | sudo -S service sends the password with admin privileges without asking the user for input
    // ------------------------ Run the command remotely ------------------------
    // " closes the "RELAUNCH_CMD" definition
    // && only runs the next part if RELAUNCH_CMD was successful
    // sshpass -p ${_lgConnectionModel.password} provides the SSH password
    // ssh -x -t lg@lg1 "$RELAUNCH_CMD" connects to lg@lg1 (the main node of the Liquid Galaxy rig) and executes the relaunch command stored in RELAUNCH_CMD

    final result = await execute(
      // Executes the execute() method remotely on the main screen
      // 'await' pauses execution until the execute() method is successfully executed
      // The result is stored in the 'result' variable

      relaunchCmd,
      // This is the value of the 'rebootCommand' parameter
      // In this case is the line used to relaunch the Liquid Galaxy

      'The Liquid Galaxy was relaunched successfully',
      // This is the 'successMessage' parameter from the execute() method
      // In this case, it informs that the relaunch was successful
    );

    return result;
    // Returns true if the execute() method returned a non-null result (for example, the command was successful)
    // Returns false otherwise
  }

  // -------- createFile() method --------
  // Used to create a file using a text string as the content
  Future<File> _createFile(String fileName, String content) async {
    // Defines an asynchronous method that returns a file object
    // 'async' allows to use 'await' inside the function
    // It also takes two parameters
    // 'fileName' is the name of the file we want to create
    // 'content' is the text content that will be written inside the file

    final directory = await getTemporaryDirectory();
    // getTemporaryDirectory() is a method from the path_provider package that gets the system's temporary folder for the app
    // await pauses execution until this method call is complete
    // The result is stored in a variable called "directory"

    final file = File('${directory.path}/$fileName');
    // Uses the File class from the dart:io package to create a file object
    // ${directory.path} inserts the full path to the temporary folder
    // $fileName appends the file name to create a full path
    // The result is stored in a variable called "file"
    // At this point THE FILE DOES NOT EXIST YET!!
    // This just creates the reference to where it will be saved

    return await file.writeAsString(content);
    // file.writeAsString(content) writes the given content into the file as plain text
    // If the file does not exist yet, it will be created
    // Returns the File object after the writing is complete
    // await pauses execution until this method call is complete
  }

  // -------- uploadKml() method --------
  // Used to upload a KML to the Liquid Galaxy
  Future<String?> uploadKml(String content, String fileName) async {
    // Defines an asynchronous method that does not return any value (void)
    // 'async' allows to use 'await' inside the function
    // It does not return any value because its function is to trigger a side-effect, not to return data
    // It also takes two parameters
    // 'content' is the text content that will be written inside the file
    // 'fileName' is the name of the file we want to create

    if (_client == null) {
      // If _client = null, this means there is no active connection, so we cannot send any KMLs

      debugPrint('The SSH client is not connected');
      // Prints the specific problem on the debug console
      // NOT VISIBLE TO USERS, only to developers in the debug console

      return null;
      // Exits the function early
    }

    try {
      // try block used to catch any exceptions that may occur

      debugPrint('Uploading KML...');
      // Informs about the state of the upload on the debug console
      // NOT VISIBLE TO USERS, only to developers in the debug console

      final randomNumber = DateTime.now().millisecondsSinceEpoch % 1000;
      // This line generates a small random number based on the current time (DateTime.now()) in milliseconds (.millisecondsSinceEpoch)
      // %1000 takes only the last theree digits to not make the number too long
      // The result is stored in a variable called "randomNumber"
      // This is used to create unique file names when uploading a KML and avoid overwriting previous KMLs

      final fileNameWithRandom = fileName.replaceAll(
        // Takes the file provided as the value of "fileName"

        '.kml',
        // Replaces this string

        '_$randomNumber.kml',
        // With this string
        // And stores the result in a variable called "fileNameWithRandom"
      );

      final sftp = await _client?.sftp();
      // _client?.sftp() gets an SFTP session from the SSH client
      // Stores the result in a variable called "sftp"
      // await waits pauses execution until the call to this method is complete

      if (sftp == null) {
        // If th SFTP session fails (sftp == null):

        throw Exception('Failed to initialize SFTP client');
        // The code throws an exception because uploading a KML is impossible without SFTP
      }

      final file = await sftp.open(
        // sftp.open() opens (or creates) the file on the remote Liquid Galaxy machine using the open() method of the sftp client
        // Stores the result in a variable called "file"
        // await pauses execution until the call of this method is complete

        '/var/www/html/$fileNameWithRandom',
        // Opens (or creates) the file inside the directory /var/www/html/

        mode: SftpFileOpenMode.truncate |
            SftpFileOpenMode.create |
            SftpFileOpenMode.write,
        // SftpFileOpenMode indicates the sftp file is in "open" mode
        // .truncate clears existing content if the file exists
        // .create creates a new file if it does not exist
        // .write allows writing to the file
      );

      final currentFile = await _createFile(fileNameWithRandom, content);
      // Calls the craetFile() method we define earlier to create a file
      // This file will be named as the value of "fileNameWithRandom" and its content will be the value of "content"
      // This file will be stored in the "currentFile" variable
      // await pauses execution until the call of this method is complete

      final fileStream = currentFile.openRead();
      // currentFile.openRead() opens the file we just created as a stream of bytes
      // This makes it possible for it to be uploaded in chunks
      // This is stored in a variable called "fileStream"

      int offset = 0;
      // The variable called "offset" is used to track how far into the file we have written on the remote side
      // We initialize it to 0 because, when we start, we have not written on the remote side yet

      await for (final chunk in fileStream) {
        // This line creates a loop that goes through each chunk of the file's bytes

        final typedChunk = Uint8List.fromList(chunk);
        // Converts every chunk to Uint8List so SFTP can handle it properly
        // Stores this converted chunk in the variable "typedChunk"

        await file.write(Stream.fromIterable([typedChunk]), offset: offset);
        // Writes every converted chunk on the remote file at the correct offset (which avoids overwrites)

        offset += typedChunk.length;
        // Increases the offset after each chunk with the lenght of said chunk so the next one is appended
      }

      await file.close();
      // Closes the remote file after writing is complete

      sftp.close();
      // Closes the SFTP session to free up the SSH channel

      await execute(
        // Executes the execute() method remotely on the main screen
        // 'await' pauses execution until the execute() method is successfully executed

        'echo "http://lg1:81/$fileNameWithRandom" > /var/www/html/kmls.txt',
        // This is the value of the 'rebootCommand' parameter
        // In this case it is a remote SSH command that runs after the upload finishes
        // This writes the file's public URL (Liquid Galaxy web server path) into /var/www/html/kmls.txt
        // This tells Liquid Galaxy which KML file to display

        'KML file written successfully',
        // This is the 'successMessage' parameter from the execute() method
        // In this case, it informs that the KML was successfully written
      );
      return fileNameWithRandom;
      // Returns the name of the final file that was uploaded
    } catch (e) {
      debugPrint('Error during KML upload: $e');
      // Prints the specific error on the debug console
      // NOT VISIBLE TO USERS, only to developers in the debug console
      return null;
    }
  }

  // -------- sendLogo() method --------
  // Sends a ScreenOverlay KML with the logo to the rig
  Future<void> sendLogo() async {
    int leftMost = calculateLeftMostScreen(_lgConnectionModel.screens);
    final kml = ScreenOverlayKmlModel.generateLogoKML();
    final uploadedName = await uploadKml(kml, 'logo_left.kml');
    if (uploadedName != null) {
      await query('slave_$leftMost=https://lg1:81/$uploadedName');
    }
  }


  // -------- sendLogo() method --------

  /*
  // Used to send logos to the furthest left screen
  Future<bool> sendLogo() async {
    // Defines an asynchronous method that returns a boolean value
    // 'async' allows to use 'await' inside the function

    String kmlContent = '''
    <?xml version="1.0" encoding="UTF-8"?>
    <kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
    <Document>
        <name>Logo</name>
        <ScreenOverlay>
            <name>Logo</name>
            <Icon>
              <href>https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgXmdNgBTXup6bdWew5RzgCmC9pPb7rK487CpiscWB2S8OlhwFHmeeACHIIjx4B5-Iv-t95mNUx0JhB_oATG3-Tq1gs8Uj0-Xb9Njye6rHtKKsnJQJlzZqJxMDnj_2TXX3eA5x6VSgc8aw/s320-rw/LOGO+LIQUID+GALAXY-sq1000-+OKnoline.png</href>
            </Icon>
            <overlayXY x="0" y="0" xunits="fraction" yunits="fraction"/>
            <screenXY x="0.02" y="0.725" xunits="fraction" yunits="fraction"/>
            <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
            <size x="554" y="500" xunits="pixels" yunits="pixels"/>
        </ScreenOverlay>
    </Document>
    </kml>''';
    // kmlContent is a variable that holds the KML string used to send logos to the remote server
    // '''...''' is a Dart syntax that allows to divide this line into multiple ones to view it better (it is not part of the command per se)
    // <?xml version="1.0" encoding="UTF-8"?> tells the parser that this is an XML file encoded using UTF-8
    // <kml></kml> is the root tag for a KML file
    // xmlns="http://www.opengis.net/kml/2.2"> is the default namespace for standard KML elements
    // xmlns:gx="http://www.google.com/kml/ext/2.2" is the Google Earth Extensions namespace
    // xmlns:kml="http://www.opengis.net/kml/2.2" is a namespace alias for standard KML elements (same as the default one, but explicitly prefixed)
    // xmlns:atom="http://www.w3.org/2005/Atom" is the Atom Syndication namespace, often used for metadata like links
    // <Document></Document> is a container for all elements in this KML file
    // <name>Logo</name> is the title or label for this document/overlay
    // It may appear in the Google Earth Layers list
    // <ScreenOverlay></ScreenOverlay> means it will draw an image on the screen NOT tied to map coordinates
    // <Icon><href>...</href></Icon> specifies the image URL (the logo)
    // overlayXY and screenXY define positioning
    // rotationXY defines rotation
    // size defines the width and height of the logo in pixels

    int leftMostScreen = calculateLeftMostScreen(_lgConnectionModel.screens);
    // Calculates which screen is the furthest to the left and stores it in the 'leftMostScreen' variable

    final result = await execute(
      // Executes the execute() method remotely on the main screen
      // 'await' pauses execution until the execute() method is successfully executed
      // The result is stored in the 'result' variable

      "echo '$kmlContent' > /var/www/html/kml/slave_$leftMostScreen.kml",
      // This is the value of the 'rebootCommand' parameter
      // In this case it is a remote SSH command that runs after the furthest left screen is calculated
      // echo '$kmlContent' outputs the KML content as text
      // > redirects that output into a file
      // /var/www/html/kml/slave_$leftMostScreen.kml saves it in the KML directory for the specific screen (the furthest one to the left)

      'Logo successfully sent to the Liquid Galaxy',
      // This is the 'successMessage' parameter from the execute() method
      // In this case, it informs that the logo was successfully sent to the Liquid Galaxy
    );

    return result != null;
    // Returns true if the execute() method returned a non-null result (for example, the command was successful)
    // Returns false otherwise
  }
  */

  // sendLogo was moved to the end of the file for better organization.

  // -------- shutdown() method --------
  // Used to shut down the Liquid Galaxy system
  Future<bool> shutdown() async {
    // Defines an asynchronous method that returns a boolean value
    // 'async' allows to use 'await' inside the function

    try {
      // try block used to catch any exceptions that may occur

      await connectToLG();
      // First of all, connects to the Liquid Galaxy system
      // This is important to make sure all commands can be sent to all screens
      // 'await' pauses execution until the connectToLG() method is successfully executed

      bool allSuccessful = true;
      // The 'allSuccessful' variable is used to track if all the commands succeeded
      // It is initialized to true because we assumme everything will succeed
      // After every command, we check if the value is still true

      for (int i = _lgConnectionModel.screens; i >= 1; i--) {
        // Loop that goes screen by screen (i) from the highest screen number (lgConnectionModel.screens) down to 1 (>= 1), decreasing one by one (i--)
        // For each screen:

        final shutdownCommand =
            'sshpass -p ${_lgConnectionModel.password} ssh -t lg$i "echo ${_lgConnectionModel.password} | sudo -S shutdown now"';
        // Creates a command that will be used to shut down the system and that is stored in the 'shutdownCommand' variable
        // sshpass -p ${_lgConnectionModel.password} provides the password automatically (without user input)
        // ssh -t lg$i runs SSH to connect to the host named lg$i (with i being the current screen number in the loop)
        // - t forces a pseudo-terminal (a virtual terminal window) allocation, making the remote server think we are typing from a real terminal
        // This makes sure that commands that depend on environment can still run
        // "echo ${_lgConnectionModel.password} | sudo -S shutdown now" is the remote command executed on the screen after connecting
        // echo ${_lgConnectionModel.password} outputs the password again
        // The pipe symbol (|) sends that password as an input to the next command (sudo)
        // sudo -S runs the following command with root (superuser) privileges, reading the password from standard input (-S)
        // sudo -S shutdown now runs the shut down command using the password

        final result = await execute(
          // Executes the execute() method remotely on the main screen
          // 'await' pauses execution until the execute() method is successfully executed
          // The result is stored in the 'result' variable

          shutdownCommand,
          // This is the value of the 'rebootCommand' parameter
          // In this case is the line used to shut down using admin privileges and without manual input of the password

          'Liquid Galaxy screen $i was shut down successfully',
          // This is the 'successMessage' parameter from the execute() method
          // In this case, it informs that a certain screen was shut down
        );

        allSuccessful = allSuccessful && result;
        // Used to track if all operations have bee successful so far
        // If allSuccessful is still true, the command continues
        // result checks if the 'result' variable (which stores the result of the execute() method) is true or not
        // If it is true, the command was successful
        // The value of this command (true or false) is updated in the 'allSuccessful' variable
        // If allSuccessful is still true, everything is going okay until now

        if (i > 1) {
          // While the screen number (i) is not 1 (the main node):

          await Future.delayed(const Duration(milliseconds: 200));
          // Future.delayed creates a Future (a value that will be available at some point in the future) that completes after a specified delay
          // const Duration(milliseconds: 200) specifies the length of that delay
          // In this case, this delay is used between shutting down each screen to prevent command overlap or network overload
        }
      }

      // ------------ Make sure the main node shuts down ------------
      final shutdownCommandLg1 =
          'sshpass -p ${_lgConnectionModel.password} ssh -t lg1 "echo ${_lgConnectionModel.password} | sudo -S shutdown now"';
      // Creates a command that will be used to make sure the main screen shuts down and that is stored in the 'shutdownCommandLg1' variable
      // sshpass -p ${_lgConnectionModel.password} provides the password automatically (without user input)
      // ssh -t lg1 runs SSH to connect to the host named lg1 (with is the main node/screen)
      // - t forces a pseudo-terminal (a virtual terminal window) allocation, making the remote server think we are typing from a real terminal
      // This makes sure that commands that depend on environment can still run
      // "echo ${_lgConnectionModel.password} | sudo -S shutdown now" is the remote command executed on the screen after connecting
      // echo ${_lgConnectionModel.password} outputs the password again
      // The pipe symbol (|) sends that password as an input to the next command (sudo)
      // sudo -S runs the following command with root (superuser) privileges, reading the password from standard input (-S)
      // sudo -S shutdown now runs the shut down command using the password

      final lg1Result = await execute(
        // Executes the execute() method remotely on the main screen
        // 'await' pauses execution until the execute() method is successfully executed
        // The result is stored in the 'lg1Result' variable

        shutdownCommandLg1,
        // This is the value of the 'rebootCommand' parameter
        // In this case is the line used to shut down the main screen using admin privileges and without manual input of the password

        'Liquid Galaxy 1 (main node) was shut down successfully',
        // This is the 'successMessage' parameter from the execute() method
        // In this case, it informs that the main screen was shut down
      );
      allSuccessful = allSuccessful && lg1Result;
      // Used to track if all operations have bee successful so far
      // If allSuccessful is still true, the command continues
      // lg1Result checks if the main screen result was true
      // If it is true, the command was successful
      // The value of this command (true or false) is updated in the 'allSuccessful' variable
      // If allSuccessful is still true, everything is going okay until now

      await Future.delayed(const Duration(milliseconds: 100));
      // Future.delayed creates a Future (a value that will be available at some point in the future) that completes after a specified delay
      // const Duration(milliseconds: 100) specifies the length of that delay
      // In this case, this delay is used to create a short pause before completely disconnecting from the Liquid Galaxy

      _handleDisconnection();
      // If the shut down was successful, we call the handleDisconnection() method to handle all the disconnection logic

      return allSuccessful;
      // Returns the final result of the shutdown() method
      // If allSuccessful = true, all operations were successful
      // If allSuccessful = false, something failed at some point
    } catch (e) {
      // Catches any errors thrown during the try block

      debugPrint('Error during shutdown: $e');
      // Prints the specific error on the debug console
      // NOT VISIBLE TO USERS, only to developers in the debug console

      _handleDisconnection();
      // If an error was caught it means the connection was lost, so we call the handleDisconnection() method to handle the situation

      return false;
      // Since the reboot was not successful, the value returned is false
    }
  }

  // -------- getScreenNumber() method --------
// Used to get the number of screens in the Liquid Galaxy system
// The one used in GSoC is 5 screens but just in case
  int getScreenNumber() {
    return _lgConnectionModel.screens;
  }

  /// Starts the tour by sending the 'playtour' query to the Liquid Galaxy.
  /// [tourName] must match the `name` tag defined in your KML <gx:Tour>.
  Future<void> startTour(String tourName) async {
    if (_client == null) {
      // If _client = null, this means there is no active connection, so we cannot send any KMLs

      debugPrint('The SSH client is not connected');
      // Prints the specific problem on the debug console
      // NOT VISIBLE TO USERS, only to developers in the debug console

      return;
      // Exits the function early
    }
    try {
      // 1. Construct the command
      // The LG listens to /tmp/query.txt for commands.
      final command = 'echo "playtour=$tourName" > /tmp/query.txt';

      // 2. Execute the command via your SSH client
      // Note: Replace '_client' with your actual SSH client variable name
      await execute(command, "Tour '$tourName' started.");
       
    } catch (e) {
      print("Error starting tour: $e");
    }
  }

  /// Stops any currently running tour.
  Future<void> stopTour() async {
    if (_client == null) {
      // If _client = null, this means there is no active connection, so we cannot send any KMLs

      debugPrint('The SSH client is not connected');
      // Prints the specific problem on the debug console
      // NOT VISIBLE TO USERS, only to developers in the debug console

      return;
      // Exits the function early
    }
    try {
      // 1. Construct the command to exit the tour
      const command = 'echo "exittour=true" > /tmp/query.txt';

      // 2. Execute the command
      await execute(command, "Tour stopped.");
       
    } catch (e) {
      print("Error stopping tour: $e");
    }
  }

  // -------- flyToDelhi() method --------
  Future<void> flyToDelhi() async {
    const lookAt = '''
      <LookAt>
        <longitude>77.2090</longitude>
        <latitude>28.6139</latitude>
        <altitude>0</altitude>
        <heading>0</heading>
        <tilt>45</tilt>
        <range>1500</range>
        <gx:altitudeMode>relativeToGround</gx:altitudeMode>
      </LookAt>
    ''';
    await flyTo(lookAt);

    const kml = '''<?xml version="1.0" encoding="UTF-8"?>
    <kml xmlns="http://www.opengis.net/kml/2.2">
      <Placemark>
        <name>Delhi</name>
        <description>Capital of India</description>
        <Point>
          <coordinates>77.2090,28.6139,0</coordinates>
        </Point>
      </Placemark>
    </kml>''';

    await uploadKml(kml, 'delhi.kml');
  }

  // -------- sendLogoToLeftmost() method --------
  // (Redundant, use sendLogo() instead)
  Future<void> sendLogoToLeftmost() async {
    await sendLogo();
  }

  // -------- create3DPyramid() method --------
  Future<void> create3DPyramid() async {
    // New York Coordinates
    double lat = 40.7128;
    double lon = -74.0060;
    double size = 0.01; // Size in degrees (roughly 1.1km)
    double altitude = 1000; // Altitude in meters

    String kml = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>3D Pyramid New York</name>
    <Placemark>
      <name>Pyramid</name>
      <styleUrl>#pyramidStyle</styleUrl>
      <MultiGeometry>
        <!-- Base -->
        <Polygon>
          <extrude>1</extrude>
          <altitudeMode>relativeToGround</altitudeMode>
          <outerBoundaryIs>
            <LinearRing>
              <coordinates>
                ${lon - size},${lat - size},$altitude
                ${lon + size},${lat - size},$altitude
                ${lon + size},${lat + size},$altitude
                ${lon - size},${lat + size},$altitude
                ${lon - size},${lat - size},$altitude
              </coordinates>
            </LinearRing>
          </outerBoundaryIs>
        </Polygon>
        <!-- Side 1 -->
        <Polygon>
          <extrude>1</extrude>
          <altitudeMode>relativeToGround</altitudeMode>
          <outerBoundaryIs>
            <LinearRing>
              <coordinates>
                ${lon - size},${lat - size},$altitude
                ${lon + size},${lat - size},$altitude
                $lon,$lat,${altitude + 2000}
                ${lon - size},${lat - size},$altitude
              </coordinates>
            </LinearRing>
          </outerBoundaryIs>
        </Polygon>
        <!-- Side 2 -->
        <Polygon>
          <extrude>1</extrude>
          <altitudeMode>relativeToGround</altitudeMode>
          <outerBoundaryIs>
            <LinearRing>
              <coordinates>
                ${lon + size},${lat - size},$altitude
                ${lon + size},${lat + size},$altitude
                $lon,$lat,${altitude + 2000}
                ${lon + size},${lat - size},$altitude
              </coordinates>
            </LinearRing>
          </outerBoundaryIs>
        </Polygon>
        <!-- Side 3 -->
        <Polygon>
          <extrude>1</extrude>
          <altitudeMode>relativeToGround</altitudeMode>
          <outerBoundaryIs>
            <LinearRing>
              <coordinates>
                ${lon + size},${lat + size},$altitude
                ${lon - size},${lat + size},$altitude
                $lon,$lat,${altitude + 2000}
                ${lon + size},${lat + size},$altitude
              </coordinates>
            </LinearRing>
          </outerBoundaryIs>
        </Polygon>
        <!-- Side 4 -->
        <Polygon>
          <extrude>1</extrude>
          <altitudeMode>relativeToGround</altitudeMode>
          <outerBoundaryIs>
            <LinearRing>
              <coordinates>
                ${lon - size},${lat + size},$altitude
                ${lon - size},${lat - size},$altitude
                $lon,$lat,${altitude + 2000}
                ${lon - size},${lat + size},$altitude
              </coordinates>
            </LinearRing>
          </outerBoundaryIs>
        </Polygon>
      </MultiGeometry>
    </Placemark>
    <Style id="pyramidStyle">
      <LineStyle>
        <color>ff0000ff</color>
        <width>2</width>
      </LineStyle>
      <PolyStyle>
        <color>7f00ffff</color>
      </PolyStyle>
    </Style>
  </Document>
</kml>''';

    await uploadKml(kml, 'pyramid.kml');
    
    // Fly to the pyramid
    final lookAt = '''
      <LookAt>
        <longitude>$lon</longitude>
        <latitude>$lat</latitude>
        <altitude>0</altitude>
        <heading>0</heading>
        <tilt>60</tilt>
        <range>5000</range>
        <gx:altitudeMode>relativeToGround</gx:altitudeMode>
      </LookAt>
    ''';
    await flyTo(lookAt);
  }
}