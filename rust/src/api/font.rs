use flutter_rust_bridge::frb;
use std::collections::HashMap;
use ttf_parser::{name_id, Face};

#[frb(opaque)]
pub struct FontReader;

impl FontReader {
    pub fn get_font_name_from_ttf(ttf_file_path: String) -> Option<String> {
        let data = match std::fs::read(ttf_file_path) {
            Ok(data) => data,
            Err(_) => return None,
        };
        let font = match Face::parse(&data, 0) {
            Ok(font) => font,
            Err(_) => return None,
        };
        font.names()
            .into_iter()
            .find(|name| name.name_id == name_id::FULL_NAME && name.is_unicode())
            .and_then(|name| name.to_string())
    }

    pub fn get_wght_axis_from_vf_font(ttf_file_path: String) -> HashMap<String, f32> {
        let mut result = HashMap::new();
        let data = match std::fs::read(ttf_file_path) {
            Ok(data) => data,
            Err(_) => return result,
        };
        let font = match Face::parse(&data, 0) {
            Ok(font) => font,
            Err(_) => return result,
        };
        let fvar = match font.tables().fvar {
            Some(fvar) => fvar,
            None => return result,
        };
        if let Some(wght_axis) = fvar
            .axes
            .into_iter()
            .find(|axis| axis.tag == ttf_parser::Tag::from_bytes(b"wght"))
        {
            result.insert("default".to_string(), wght_axis.def_value);
        }
        for instance in fvar.instances() {
            if let Some(name) = font
                .names()
                .into_iter()
                .find(|n| n.name_id == instance.subfamily_name_id && n.is_unicode())
            {
                let subfamily = name.to_string().unwrap_or_default();
                for (axis, value) in fvar.axes.into_iter().zip(instance.user_tuples) {
                    if axis.tag == ttf_parser::Tag::from_bytes(b"wght") {
                        result.insert(subfamily, value.0);
                        break;
                    }
                }
            }
        }
        result
    }
}
