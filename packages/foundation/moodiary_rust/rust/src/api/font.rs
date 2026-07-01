use anyhow::{Context, Result};
use flutter_rust_bridge::frb;
use std::collections::HashMap;
use ttf_parser::{name_id, Face};

#[frb(opaque)]
pub struct FontReader {}

impl FontReader {
    pub fn get_font_name_from_ttf(ttf_file_path: String) -> Result<String> {
        let data = std::fs::read(&ttf_file_path)
            .with_context(|| format!("Failed to read font file: {}", ttf_file_path))?;
        let font = Face::parse(&data, 0)
            .map_err(|_| anyhow::anyhow!("Failed to parse font: {}", ttf_file_path))?;

        font.names()
            .into_iter()
            .find(|name| name.name_id == name_id::FULL_NAME && name.is_unicode())
            .and_then(|name| name.to_string())
            .ok_or_else(|| anyhow::anyhow!("Font has no name: {}", ttf_file_path))
    }

    pub fn get_wght_axis_from_vf_font(ttf_file_path: String) -> Result<HashMap<String, f32>> {
        let mut result = HashMap::new();
        let data = std::fs::read(&ttf_file_path)
            .with_context(|| format!("Failed to read font file: {}", ttf_file_path))?;
        let font = Face::parse(&data, 0)
            .map_err(|_| anyhow::anyhow!("Failed to parse font: {}", ttf_file_path))?;

        let fvar = font
            .tables()
            .fvar
            .ok_or_else(|| anyhow::anyhow!("Font has no fvar table: {}", ttf_file_path))?;

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
        Ok(result)
    }
}
