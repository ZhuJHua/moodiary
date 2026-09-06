pub mod client;
pub mod request;
pub mod server;

#[derive(Clone)]
pub struct KeyValue {
    pub key: String,
    pub value: String,
}
