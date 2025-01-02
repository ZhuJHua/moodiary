import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:mood_diary/utils/function_extensions.dart';

import 'login_form_logic.dart';

class LoginFormComponent extends StatelessWidget {
  const LoginFormComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(LoginFormLogic());
    final state = Bind.find<LoginFormLogic>().state;
    final size = MediaQuery.sizeOf(context);
    return GetBuilder<LoginFormLogic>(
      builder: (_) {
        return GestureDetector(
          onTap: () {
            logic.emailFocusNode.unfocus();
            logic.passwordFocusNode.unfocus();
          },
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: SizedBox(
              width: min(300, size.width / 1.618),
              child: Form(
                key: state.formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '邮箱',
                      ),
                      onSaved: (value) {
                        state.email = value!;
                      },
                      onChanged: (value) {
                        state.email = value;
                      },
                      validator: (value) {
                        return (value == null || !GetUtils.isEmail(value))
                            ? '请输入邮箱'
                            : null;
                      },
                      focusNode: logic.emailFocusNode,
                    ),
                    const SizedBox(
                      height: 20.0,
                    ),
                    TextFormField(
                      validator: (value) {
                        if (value!.isEmpty) {
                          return '请输入密码';
                        } else if (value.length < 6) {
                          return '密码最少六位';
                        } else {
                          return null;
                        }
                      },
                      onSaved: (value) {
                        state.password = value!;
                      },
                      onChanged: (value) {
                        state.password = value;
                      },
                      obscureText: true,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: '密码',
                      ),
                      focusNode: logic.passwordFocusNode,
                    ),
                    const SizedBox(
                      height: 20.0,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                            onPressed: () {
                              logic.loginLogic.changeForm();
                            },
                            child: const Text("注册")),
                        ElevatedButton(
                          onPressed: () {
                            logic.submit();
                          }.throttleWithTimeout(timeout: 5000),
                          child: const Icon(Icons.login),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
