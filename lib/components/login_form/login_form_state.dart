import 'package:flutter/material.dart';

class LoginFormState {
  final formKey = GlobalKey<FormState>();

  late String email;
  late String password;

  LoginFormState() {
    email = '';
    password = '';

    ///Initialize variables
  }
}
