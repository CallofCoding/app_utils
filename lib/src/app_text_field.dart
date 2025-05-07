import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String errorMsg;
  final String? helperText;
  final TextStyle? helperTextStyle;
  final String? hint;
  final TextStyle? hintTextStyle;
  final EdgeInsetsGeometry? contentPadding;
  final bool isTextFieldForEmail;
  final bool? isTextFieldForPassword;
  final bool isOptional;
  final bool? filled;
  final Color? fillColor;
  final bool? readOnly;
  final String? initialValue;
  final String? label;
  final BoxConstraints? constraints;
  final int maxHelperLines;
  final void Function()? onTap;
  final int maxLines;
  final TextInputType? keyboardType;
  final int? maxLengthOfInputFormatter;
  final void Function(String?)? onSaved;
  final bool isFieldForCNIC; //if ture then it shows error if the field.length is > 13 or < 13;
  final bool isDense;
  final double? borderRadius;
  final Widget? prefix;
  final Widget? suffix;
  final String? errorText;
  final void Function(String)? onChanged;
  const AppTextField(
      {super.key,
        this.controller,
        required this.errorMsg,
        this.helperText,
        this.helperTextStyle,
        this.hint,
        this.hintTextStyle,
        this.contentPadding,
        this.filled,
        this.fillColor,
        this.maxLines = 1,
        this.keyboardType,
        this.maxLengthOfInputFormatter,
        this.isFieldForCNIC = false,
        this.maxHelperLines = 1,
        this.isOptional = false,
        this.isTextFieldForEmail = false,
        this.onTap,
        this.readOnly,
        this.onSaved, this.initialValue, this.constraints, this.label,this.isDense = true, this.borderRadius, this.prefix, this.suffix,this.isTextFieldForPassword, this.onChanged, this.errorText});

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {

  bool? obscureText;

  void showHidePassword(){
    setState(() {
      if(obscureText != null){
        obscureText = !obscureText!;
      }
    });
  }

  @override
  void initState() {
    if(widget.isTextFieldForPassword == true){
      obscureText = true;
    }
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onSaved: widget.onSaved,
      initialValue: widget.initialValue,

      onTapOutside: (event) {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      onChanged: widget.onChanged,
      readOnly: widget.readOnly ?? false,
      onTap: widget.onTap,
      validator: (value) {
        if (!widget.isOptional) {
          if (value == null || value.isEmpty) {
            return widget.errorMsg;
          }
          if (widget.isFieldForCNIC) {
            if (value.length != 13) {
              return 'Invalid CNIC';
            }
          }
          if (widget.isTextFieldForEmail) {
            RegExp regExpEmail = RegExp(
              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
            );
            if (!regExpEmail.hasMatch(value)) {
              return 'Invalid Email';
            }
          }
        }
        return null;
      },
      inputFormatters: widget.maxLengthOfInputFormatter == null
          ? []
          : [
        LengthLimitingTextInputFormatter(widget.maxLengthOfInputFormatter)
      ],
      keyboardType: widget.keyboardType,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      maxLines: widget.maxLines,
      controller: widget.controller,
      cursorColor: Colors.black,
      obscureText: obscureText ?? false,
      decoration: InputDecoration(
          labelText: widget.label,
          constraints: widget.constraints,
          errorText: widget.errorText,
          isDense: widget.isDense,
          contentPadding: widget.contentPadding ?? EdgeInsets.all(12),
          hintText: widget.hint,
          hintStyle: widget.hintTextStyle,
          helperStyle: widget.helperTextStyle,
          helperText: widget.helperText,
          helperMaxLines: widget.maxHelperLines,
          filled: widget.filled,
          fillColor: widget.fillColor,
          prefixIcon: widget.prefix,
          suffixIcon: obscureText == null ? widget.suffix : IconButton(
              onPressed: showHidePassword,
              splashRadius: 20,
              icon: Icon(obscureText == true ? CupertinoIcons.eye_slash_fill : CupertinoIcons.eye_fill)
          ) ,
          prefixIconConstraints: BoxConstraints(),
          suffixIconConstraints: BoxConstraints(),
          border: inputBorder(enableBorder: true),
          focusedBorder: inputBorder(enableBorder: true,color: Theme.of(context).primaryColor),
          enabledBorder: inputBorder(enableBorder: true),
          errorBorder: inputBorder(
            enableBorder: true,
            color: Colors.red,
          )),
    );
  }


  InputBorder inputBorder(
      {bool enableBorder = false, Color color = Colors.black12}) {
    return OutlineInputBorder(
        borderRadius: BorderRadius.circular(widget.borderRadius ?? 40),
        borderSide: BorderSide(
            style: enableBorder == false ? BorderStyle.none : BorderStyle.solid,
            color: color));
  }
}
