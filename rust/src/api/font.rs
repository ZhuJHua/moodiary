use flutter_rust_bridge::frb;
use std::fs::File;
use std::io::Read;
use ttf_parser::{name_id, Face};

#[frb(opaque)]
pub struct FontReader;

impl FontReader {
    pub fn get_font_name_from_ttf(ttf_file_path: String) -> Option<String> {
        let file = File::open(ttf_file_path);
        match file {
            Ok(mut f) => {
                let mut data = Vec::new();
                if f.read_to_end(&mut data).is_ok() {
                    let font = Face::parse(&data, 0).ok()?;
                    font.names()
                        .into_iter()
                        .find(|name| name.name_id == name_id::FULL_NAME && name.is_unicode())
                        .and_then(|name| name.to_string())
                } else {
                    None
                }
            }
            Err(_) => None,
        }
    }
}
