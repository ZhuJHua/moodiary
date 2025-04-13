import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:moodiary/utils/function_extensions.dart';

import 'register_form_logic.dart';

class RegisterFormComponent extends StatelessWidget {
  const RegisterFormComponent({super.key});

  @override
  Widget build(BuildContext context) {
    final logic = Get.put(RegisterFormLogic());
    final state = Bind.find<RegisterFormLogic>().state;
    final size = MediaQuery.sizeOf(context);
    return GetBuilder<RegisterFormLogic>(
      builder: (_) {
        return GestureDetector(
          onTap: () {
            logic.unFocus();
          },
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: SizedBox(
              width: min(300, size.width / 1.618),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Form(
                    key: state.formKey,
                    child: Column(
                      children: [
                        TextFormField(
                          onSaved: (value) {
                            state.email = value!;
                          },
                          onChanged: (value) {
                            state.email = value;
                          },
                          validator: (value) {
                            return (value == null) ? '请输入邮箱' : null;
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '邮箱',
                          ),
                          focusNode: logic.emailFocusNode,
                        ),
                        const SizedBox(height: 20),
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
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '密码',
                          ),
                          focusNode: logic.passwordFocusNode,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          validator: (value) {
                            if (value!.isEmpty) {
                              return '请输入密码';
                            } else if (value != state.password) {
                              return '两次密码不一致';
                            } else {
                              return null;
                            }
                          },
                          onChanged: (value) {
                            state.rePassword = value;
                          },
                          onSaved: (value) {
                            state.rePassword = value!;
                          },
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            labelText: '确认密码',
                          ),
                          focusNode: logic.rePasswordFocusNode,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () {
                          logic.loginLogic.changeForm();
                        },
                        child: const Text("返回登录"),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          logic.submit();
                        }.throttleWithTimeout(timeout: 5000),
                        child: const Icon(Icons.check),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
