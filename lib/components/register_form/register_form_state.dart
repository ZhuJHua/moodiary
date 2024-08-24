import 'package:flutter/material.dart';

class RegisterFormState {
  final formKey = GlobalKey<FormState>();

  late String email;
  late String password;
  late String rePassword;
  late String token;

  RegisterFormState() {
    email = '';
    password = '';
    rePassword = '';
    token = '';

    ///Initialize variables
  }
}
